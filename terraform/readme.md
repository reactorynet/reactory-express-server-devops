# Reactory Terraform

Infrastructure-as-code for deploying the Reactory platform on AWS, DigitalOcean
and Linode, plus a local minikube setup. Terraform >= 1.8.0.

## Choosing a cloud

| | AWS | DigitalOcean | Linode |
|---|---|---|---|
| Environments | dev, staging, production | small, medium, large | small, medium, large |
| PostgreSQL | Aurora Serverless v2 | Managed `pg` | Managed PostgreSQL |
| MongoDB | DocumentDB | Managed `mongodb` | **pod only** |
| Valkey | ElastiCache | Managed `valkey` | **pod only** |
| Search | OpenSearch Service | Managed `opensearch` | **Meilisearch pod only** |
| Secrets | Secrets Manager + ESO | Kubernetes Secrets in state | Kubernetes Secrets in state |
| State locking | DynamoDB | none | none |
| Registry | ECR | GHCR | GHCR |

**Linode has no managed MongoDB, Redis or search** — verified against the
provider, not the marketing pages. Reactory's primary datastore is MongoDB, so a
large Linode deployment runs it as a single pod with no managed failover or
backup. See `linode/readme.md` before choosing it for production; DigitalOcean
covers the whole stack and is the better non-AWS production target.

## Architecture

Three layers, applied in order. Each is a separate Terraform state. Every cloud
uses the same shape.

```
terraform/
  modules/
    kubernetes/                # CLOUD-NEUTRAL — used by every cloud
      reactory_app/            #   express-server + pwa-client, Services, HPA,
                               #   PDB, Ingress, and the app's env contract
      app_secrets/             #   native Secrets (DigitalOcean, Linode)
      ingress_nginx/           #   ingress-nginx + cert-manager + ClusterIssuer
        chart/
      mongodb_selfhosted/      #   non-production data services
      postgres_selfhosted/
      valkey_selfhosted/
      meilisearch/
      observability/           #   kube-prometheus-stack + Jaeger
    digitalocean/
      doks/                    #   cluster + VPC + node pool
      database/                #   any managed engine, + firewall
    linode/
      lke/
      database/                #   PostgreSQL (the only engine Linode offers)

  aws/
    bootstrap/                 # LAYER 1 — account-level, applied once
                               #   S3 state bucket, DynamoDB lock table,
                               #   shared ECR registry
    modules/                   # AWS-specific
      # AWS infrastructure
      vpc/                     # VPC, subnets, NAT gateways, route tables
      eks/                     # cluster, node groups, IRSA OIDC, add-ons
      ecr/                     # container repositories
      rds/                     # Aurora PostgreSQL Serverless v2
      documentdb/              # Amazon DocumentDB (MongoDB-compatible)
      elasticache_valkey/      # ElastiCache for Valkey
      opensearch/              # Amazon OpenSearch Service
      secrets_manager/         # Secrets Manager entries + ESO's IRSA role
      external_secrets/        # ESO + ClusterSecretStore + ExternalSecrets
        chart/                 #   local Helm chart carrying the custom resources
      alb_ingress/             # AWS Load Balancer Controller + ACM
    environments/
      dev/
        cluster/               # LAYER 2 — cloud resources
        workload/              # LAYER 3 — Kubernetes objects + the app
      staging/{cluster,workload}
      production/{cluster,workload}

  digitalocean/
    bootstrap/                 # Spaces bucket for state
    environments/
      small/{cluster,workload}
      medium/{cluster,workload}
      large/{cluster,workload}

  linode/
    bootstrap/                 # Object Storage bucket for state
    environments/
      small/{cluster,workload}
      medium/{cluster,workload}
      large/{cluster,workload}

  minikube/                    # local development, self-contained
```

`modules/kubernetes/reactory_app` is the reason the clouds stay consistent: it
speaks only the Kubernetes API and owns the application's environment contract,
so all nine environments across three clouds compose the same code. Anything
provider-specific — ALB versus ingress-nginx annotations, managed versus
in-cluster endpoints — arrives through variables.

### Why the cluster/workload split

The `kubernetes` and `helm` providers have to be configured with a cluster
endpoint and CA. If that comes from `module.eks` outputs in the same state, the
provider configuration is unknown until apply. Creating resources usually works,
but `terraform destroy` and cluster replacement are unreliable: Terraform has to
configure a provider to plan the destruction of objects on a cluster it is
simultaneously destroying.

The workload layer reads those values from the cluster layer's state via
`terraform_remote_state`, which Terraform resolves during plan. The provider
configuration is therefore always known before anything is created, and the
ordering problem disappears.

The split also draws a useful blast-radius line: routine deployments only touch
the workload layer. `bin/bit.sh` will not apply the cluster layer unless you pass
`--cluster`.

### Why ECR is shared

The repositories live in `bootstrap`, not per environment, for two reasons.

Repository names are not environment-scoped, so an environment-owned registry
means dev and production race for the same two repositories — whichever applies
second fails with `RepositoryAlreadyExists`, and a dev teardown with
`force_delete` could remove images production is running.

More importantly it enables promotion: build and push an image once, then move
`image_tag` forward through dev → staging → production. What reaches production
is the artifact that was tested, not a separate build of the same commit.

## Environments

| | dev | staging | production |
|---|---|---|---|
| Compute | SPOT t3.medium/large, 1 AZ | ON_DEMAND t3.large, 2 AZ | ON_DEMAND m6a/m6i.large, 2 AZ |
| NAT gateways | 1 | 1 | one per AZ |
| MongoDB | pod + gp3 EBS | DocumentDB, 1 instance | DocumentDB, 2 instances |
| PostgreSQL | pod + gp3 EBS | Aurora Serverless v2, 1 | Aurora Serverless v2, writer + reader |
| Cache | Valkey `cache.t4g.small` | Valkey `cache.t4g.small` | Valkey `cache.r7g.large`, Multi-AZ |
| Search | Meilisearch pod | OpenSearch `t3.small.search` | OpenSearch `r6g.large.search`, 2 nodes |
| HPA / PDB / spread | off | on | on |
| Deletion protection | n/a | off | on |
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |

`staging` deliberately mirrors production's *service choices* while shrinking
their *size*. It uses DocumentDB and OpenSearch rather than the cheaper pods,
because TLS requirements, connection strings and the search provider code path
are exactly what a pre-production environment needs to exercise. It shrinks
instance counts and turns off deletion protection so it stays disposable.

## Getting started

### 1. Bootstrap the account (once)

```bash
cd aws/bootstrap
cp terraform.tfvars.example terraform.tfvars   # set a globally unique bucket name
terraform init
terraform apply
terraform output
```

This layer keeps **local state** — it creates the bucket that remote state lives
in, so it cannot store its own state there.

Record the outputs in `config/<config>/.env.<env>`:

```bash
TF_STATE_BUCKET=reactory-terraform-state-...
TF_STATE_REGION=us-west-1
TF_STATE_LOCK_TABLE=reactory-terraform-lock
```

`bin/terraform.sh` turns those into the `-backend-config` arguments every other
layer needs, and into the `state_bucket` variable the workload layers read.

### 2. Supply secrets

Never in `terraform.tfvars` — it is gitignored for that reason.

```bash
export TF_VAR_mongo_username="..."
export TF_VAR_mongo_password="..."
export TF_VAR_postgres_username="..."
export TF_VAR_postgres_password="..."
export TF_VAR_valkey_auth_token="..."       # 16-128 chars, no / " @
export TF_VAR_meilisearch_master_key="..."  # dev only
export TF_VAR_opensearch_username="..."     # staging + production
export TF_VAR_opensearch_password="..."     # upper, lower, digit, symbol
export TF_VAR_grafana_admin_password="..."
export TF_VAR_app_secret_key="..."          # becomes SECRET_SAUCE
```

### 3. Apply an environment

```bash
bin/terraform.sh apply --target=dev/cluster  --reactory-env=dev
bin/terraform.sh apply --target=dev/workload --reactory-env=dev --image-tag=1.1.0
```

``bin/terraform.sh --list` shows every target. Or use the build pipeline, which
builds, pushes and applies:

```bash
bin/bit.sh reactory dev --env=dev --auto-approve
```

### 4. Update kubeconfig

```bash
$(bin/terraform.sh output -raw kubeconfig_command --target=dev/cluster --reactory-env=dev --log-level=)
```

## Promoting a release

The registry is shared, so promotion moves a tag rather than rebuilding:

```bash
# build once, push once, deploy to dev
bin/bit.sh reactory dev --env=dev --image-tag=1.2.0 --auto-approve

# same artifact to staging, then production — no rebuild
bin/bit.sh reactory staging    --env=staging    --image-tag=1.2.0 --skip-build --auto-approve
bin/bit.sh reactory production --env=production --image-tag=1.2.0 --skip-build
```

Note the two repositories version independently — `reactory-express-server` and
`reactory-pwa-client` each tag from their own `package.json`. `bin/bit.sh` retags
both under the single deployment tag, because an environment has one `image_tag`.

## How secrets reach the pods

1. The **cluster layer** writes each credential to Secrets Manager under
   `<project>/<environment>/<service>`, and creates the IRSA role scoped to
   exactly those ARNs (`modules/secrets_manager`).
2. The **workload layer** installs External Secrets Operator, annotated with that
   role, and applies a `ClusterSecretStore` plus one `ExternalSecret` per service
   (`modules/external_secrets`).
3. ESO projects each into a native Kubernetes Secret in the namespace.
4. `reactory_app` references those Secrets through
   `module.external_secrets.kubernetes_secret_names[...]`, never a literal name.

No credential is written to a Kubernetes object by Terraform, so none appears in
state as one.

The custom resources are delivered by a local Helm chart rather than
`kubernetes_manifest`, which requires a reachable API server *and* a registered
CRD at plan time — impossible on a first apply, where the ESO CRDs do not exist
yet.

## Application environment contract

`modules/reactory_app` owns this. All three environments compose the same module,
so they cannot drift apart on variable names. Each name is verifiable in source:

| Purpose | Environment variables | Read by |
|---------|----------------------|---------|
| MongoDB | `MONGOOSE` (full URI) | `src/models/mongoose/index.ts`, `src/constants/index.ts` |
| PostgreSQL | `REACTORY_POSTGRES_HOST`, `_PORT`, `_USER`, `_PASSWORD`, `_DB` | `src/database/postgres/ConnectionFactory.ts` |
| Redis / Valkey | `REACTORY_REDIS_HOST`, `_PORT`, `_PASSWORD`, `_DB` | `src/modules/reactory-core/services/RedisService.ts` |
| Meilisearch | `MEILISEARCH_HOST`, `MEILISEARCH_MASTER_KEY` | `services/search/providers/MeiliSearchProvider.ts` |
| OpenSearch | `ELASTICSEARCH_NODE`, `ELASTICSEARCH_USERNAME`, `ELASTICSEARCH_PASSWORD` | `services/search/providers/ElasticSearchProvider.ts` |
| Search backend | `REACTORY_SEARCH_PROVIDER` (`meilisearch` \| `elasticsearch`) | `services/ReactorySearchService.ts` |
| Sessions / JWT | `SECRET_SAUCE`, `SESSION_SECRET` | `src/express/middleware/ReactorySession.ts`, `src/utils/encoding/encode.ts` |
| HTTP | `API_PORT`, `API_URI_ROOT`, `CDN_ROOT` | `src/express/server.ts` |

Two things are easy to get wrong here:

- **Never set `SERVER_IP`.** `server.ts` passes it straight to
  `httpServer.listen()`. Leaving it unset binds to all interfaces, which is what
  probes and Services need.
- **`$(VAR)` ordering matters.** Kubernetes expands `$(VAR)` in an env value only
  against variables declared *earlier* in the same list. `MONGOOSE` interpolates
  the credentials, so `MONGO_USER` and `MONGO_PASSWORD` are emitted before it.
  The provider models `env` as an ordered list (`nesting_mode = list`), so the
  order in `reactory_app` is preserved verbatim — but reordering it would put the
  literal string `$(MONGO_PASSWORD)` into the connection URI.

To inspect the contract without a cluster:

```bash
terraform -chdir=aws/environments/dev/workload output server_environment_variables
terraform -chdir=aws/environments/dev/workload output mongoose_uri_template
```

## Validating changes without applying

```bash
bin/terraform-verify.sh          # report problems
bin/terraform-verify.sh --fix    # also apply terraform fmt
```

| Check | Catches |
|-------|---------|
| `terraform fmt` | non-canonical formatting (`.tf` only) |
| `terraform init -backend=false` + `validate` | syntax, provider schemas, module wiring, bad output and variable references |
| `helm lint` + `helm template` | local charts that would fail to render at apply time |
| `bin/utils/check-secret-refs.py` | a workload requesting a Secret its cluster layer never enabled, or a key the schema never projects |
| `bin/utils/check-layer-contract.py` | a workload reading a cluster output that does not exist, or a state key mismatch between the layers |

Nothing here contacts AWS. Provider downloads go to a scratch `TF_DATA_DIR` with
a shared `TF_PLUGIN_CACHE_DIR`, so verifying never leaves a backend-less working
directory behind for `bin/terraform.sh` to trip over.

The last two checks exist because Terraform structurally cannot do them. Secret
names and keys are plain strings, and remote state outputs resolve at runtime —
both validate cleanly and fail only at apply, after the cluster layer is already
built.

**Not covered:** `terraform plan` needs real AWS credentials, because
`alb_ingress` and `opensearch` call `aws_caller_identity` at plan time. Run a plan
against a throwaway account before any first apply.

Requires `terraform` (`brew install hashicorp/tap/terraform` — no longer in
homebrew-core) and `helm`.

### Provider lock files

`.terraform.lock.hcl` is intentionally **not** gitignored — Terraform expects it
committed so every checkout resolves identical provider versions.

Generate them for every platform that will run Terraform before committing. A
lock file written by a local `init` on a Mac records only `darwin_arm64` hashes,
and a Linux CI runner then fails with "the lock file does not contain a hash for
this platform":

```bash
terraform -chdir=aws/environments/dev/cluster providers lock \
  -platform=darwin_arm64 -platform=linux_amd64
```

This downloads each provider for each platform, so budget a few minutes per
layer. None are committed yet — do this before wiring up CI.

## Known gaps

Tracked, not yet fixed:

- **Valkey TLS.** ElastiCache requires transit encryption whenever an AUTH token
  is set, and the module enables it. `RedisService` and `BullMessageQueueService`
  construct `ioredis` clients with no `tls` option, so the connection fails the
  handshake. The blueprints export `REACTORY_REDIS_TLS=true` in anticipation; the
  client needs to honour it (`tls: {}` when set).
- **Aurora PostgreSQL TLS.** `ConnectionFactory` passes no `ssl` option to
  `postgres.js`. Newer Aurora PostgreSQL engine versions default
  `rds.force_ssl=1`, which would refuse the connection. Confirm the engine's
  parameter group before the first staging apply.
- **Credentials in git.** `terraform/minikube/terraform.tfvars` is tracked and
  contains real passwords. `.gitignore` does not affect already-tracked files —
  this needs `git rm --cached` plus rotation.

## Region notes

`us-west-1` has only two availability zones (`us-west-1a`, `us-west-1c`) and all
defaults are sized for it. For a 3-AZ region, override `availability_zones`,
`public_subnet_cidrs` and `private_subnet_cidrs` together.

## Local development

`minikube/` is a self-contained local setup requiring no AWS credentials. Deploy
with `bin/bit.sh reactory local` (the default `--env=minikube`).
