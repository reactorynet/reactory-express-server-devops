# Reactory on an existing DigitalOcean Kubernetes cluster (`digitalocean/primary`)

Deploys the Reactory stack onto a **DOKS cluster that already exists** — one that
was not created by Terraform and therefore has no cluster layer, no Spaces
remote state, and no `doctl`-based provider auth.

This is the blueprint to use when the cluster is provisioned out of band (DO
console, `doctl`, a different tool) and you want the same application contract
as the other blueprints without adopting the cluster.

## What it deploys

| Component | Module | Notes |
|---|---|---|
| Express / Apollo backend | `modules/kubernetes/reactory_app` | `reactory-express-server` + `/reactory/reactory-data` PVC |
| Reactory PWA client | `modules/kubernetes/reactory_app` | primary client (`reactory-pwa-client`) |
| BookTutor client | `modules/kubernetes/reactory_app` → `additional_clients` | `booktutor-pwa-client` |
| Solar Compute client | `modules/kubernetes/reactory_app` → `additional_clients` | `compute-planner-pwa-client` (image must be published) |
| Social Eyes | `additional_clients` (gated) | **off by default** — see below |
| MongoDB, PostgreSQL, Valkey, Meilisearch | `*_selfhosted` / `meilisearch` | all in-cluster pods |
| Ingress + TLS | `modules/kubernetes/ingress_nginx` | ingress-nginx + cert-manager / Let's Encrypt |
| Telemetry | `modules/kubernetes/observability` | kube-prometheus-stack (Prometheus/Grafana/Alertmanager) + Jaeger, exposed behind the ingress |

## Hostnames

The stack takes the primary names for the zone by default (`host_prefix = ""`):

| Purpose | Host |
|---|---|
| Reactory web (apex) | `reactory.net` |
| API / GraphQL / CDN | `api.reactory.net` |
| BookTutor | `apex.reactory.net` |
| Solar Compute | `compute.reactory.net` |
| Grafana | `grafana.reactory.net` |
| Prometheus | `prometheus.reactory.net` |
| Jaeger | `jaeger.reactory.net` |

A records are created by this layer (DigitalOcean DNS). Set `host_prefix` to
stage a parallel set under a sub-domain instead (e.g. `doks` →
`doks.reactory.net`, `api.doks.reactory.net`, …) or `manage_dns = false` to
manage DNS elsewhere.

### DNS migration

This zone previously pointed `@`, `apex`, `api`, `app` and `booktutor` at the
old Linode load balancer. Those records must be removed or replaced before the
new cluster can serve them, otherwise DNS will return the dead address
alongside the live one:

```bash
# list the current A records and their ids
DIGITALOCEAN_TOKEN=... curl -s -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
  "https://api.digitalocean.com/v2/domains/reactory.net/records?per_page=200"
```

Either import the surviving names into this layer's state so Terraform updates
them in place, or delete the stale records and let phase 2 recreate them:

```bash
terraform -chdir=config/reactory/terraform/digitalocean/primary/workload \
  import 'digitalocean_record.app["web"]' reactory.net,<record-id>
```

## Usage

```bash
cd reactory-express-server

# non-secret settings live in terraform.tfvars (copy from the example)
cp config/reactory/terraform/digitalocean/primary/workload/terraform.tfvars.example \
   config/reactory/terraform/digitalocean/primary/workload/terraform.tfvars

# 1. plan
bin/terraform.sh plan --target=digitalocean/primary/workload --reactory-env=digitalocean

# 2. apply (phase 1 — data services, ingress, app, telemetry; no DNS yet)
bin/terraform.sh apply --target=digitalocean/primary/workload --reactory-env=digitalocean

# 3. read the load balancer IP
terraform -chdir=config/reactory/terraform/digitalocean/primary/workload output load_balancer_ip

# 4. set it and apply again (phase 2 — A records created, cert-manager completes challenges)
#    add to .env.digitalocean:  TF_VAR_load_balancer_ip=<ip>
bin/terraform.sh apply --target=digitalocean/primary/workload --reactory-env=digitalocean
```

The A records are keyed on `var.load_balancer_ip` being non-empty, so Terraform's
`for_each` key set stays statically known (an IP discovered mid-apply cannot be
used as a `for_each` key).

### Why two phases

The load balancer IP does not exist until ingress-nginx has been created, and
the ACME HTTP-01 challenge needs the A records to resolve. The first apply
creates the ingress and skips DNS (`load_balancer_ip` is null); the second
creates the A records from the now-known IP and cert-manager issues the
certificates.

## Credentials

* **Kubeconfig** — the kubernetes/helm providers read `kubeconfig_path`
  directly. No `doctl`, no expiring in-cluster token.
* **Registry** — images are private GHCR. `beforerun.sh` fills
  `TF_VAR_registry_username` / `TF_VAR_registry_token` from the `gh` CLI
  (`gh api user`, `gh auth token`); override with a classic PAT that has
  `read:packages` if the OAuth token is rejected.
* **Secrets** — supplied as `TF_VAR_*` from `config/reactory/.env.digitalocean`
  and written into Kubernetes Secrets. **They therefore live in this layer's
  Terraform state** — keep the state file private. There is no remote backend
  configured by default (local state); add one before this is shared.

## State

Local state by default, which is why `bin/terraform.sh` needs no backend
arguments for this target. For a shared/production setup, add an S3-compatible
backend (DigitalOcean Spaces) and a private, versioned bucket, exactly as the
`digitalocean/bootstrap` layer does for the other tiers.

## Social Eyes

The SocialEyes **module** ships in the express server
(`src/modules/reactory-socialeyes`, runtime widgets under
`reactory-data/plugins/__runtime__/`). There is currently **no SocialEyes client
config and no SocialEyes client image**, so `deploy_socialeyes` is `false` and
the app is not deployed. Enabling it requires:

1. a client config under `src/data/clientConfigs/socialeyes/` (routes, menus, themes, settings), and
2. a built/pushed `ghcr.io/reactorynet/socialeyes-pwa-client` image,

then `deploy_socialeyes = true`.

## Known follow-ups

* `modules/kubernetes/reactory_app` hard-codes `I18N_NS` without a `socialeyes`
  namespace; add it (or the namespace will not load) when Social Eyes is enabled.
* The `compute-planner-pwa-client` image does not exist in GHCR yet and must be
  built and pushed before the workload will roll out.
* Grafana is served at `/` on its host; a `root_url` override may be wanted if
  it is ever moved to a sub-path.
