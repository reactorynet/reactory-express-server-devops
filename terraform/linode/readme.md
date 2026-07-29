# Reactory on Linode (Akamai Cloud)

Three tiers on Linode Kubernetes Engine, sharing the same modules and the same
application contract as the AWS and DigitalOcean blueprints.

## Read this before choosing Linode

**Akamai's Linode Managed Databases offer MySQL and PostgreSQL, and nothing
else.** There is no managed MongoDB, no managed Redis or Valkey, and no managed
search service. The MongoDB and Redis engines announced when the product
launched were beta and have been withdrawn.

Verified directly against the Terraform provider rather than the marketing
pages, which still cite the 2022 launch announcement:

```
linode_database_mysql_v2       exists
linode_database_postgresql_v2  exists
linode_database_mongodb        does not exist
linode_database_redis          does not exist
```

The consequence is structural, not a configuration choice: **MongoDB, Valkey and
search run as in-cluster pods at every Linode tier, including large.** Single
instances on block storage, with no managed failover, no automated backup and no
point-in-time recovery.

Reactory stores its primary application data in MongoDB. If that data matters,
a large Linode deployment is not equivalent to the DigitalOcean or AWS large
tiers, and you should either:

- deploy production on DigitalOcean, whose managed engines cover `pg`,
  `mongodb`, `valkey` and `opensearch`; or
- point the `mongo` block in the workload layer at an external managed MongoDB
  (Atlas, or a DigitalOcean managed cluster reached over the internet).

Linode remains a good fit for the small and medium tiers, where everything is
disposable anyway and the per-node price is competitive.

## Tiers

| | small | medium | large |
|---|---|---|---|
| Nodes | 1 × g6-standard-2 (4GB) | 2 × g6-standard-2 | 3-8 × g6-standard-4, autoscaling |
| Control plane HA | no | no | **yes (irreversible)** |
| PostgreSQL | pod | Managed, 1 node | Managed, 3-node HA |
| MongoDB | pod | pod | **pod** |
| Valkey | pod | pod | **pod** |
| Search | Meilisearch pod | Meilisearch pod | **Meilisearch pod** |
| HPA / PDB | off | on | on |
| Ingress replicas | 1 | 2 | 2 |
| TLS | optional | optional | on by default |
| VPC subnet | 10.20.0.0/24 | 10.21.0.0/24 | 10.22.0.0/24 |

`high_availability` on an LKE control plane **cannot be turned off again**.
Setting it back to false forces the cluster to be replaced. It is enabled only
at the large tier.

## Requirements

- Terraform >= 1.8, and the Linode provider **>= 4.0**. VPC support for LKE and
  private networking for Managed Databases do not exist in provider 2.x; without
  them the database is reachable only over a public endpoint behind an IP
  allow-list, which does not compose with an autoscaling node pool.
- `linode-cli` for kubeconfig retrieval.
- A GitHub Container Registry repository for the images — Linode has no
  container registry of its own.

## Getting started

### 1. Bootstrap (once per account)

```bash
cd linode/bootstrap
cp terraform.tfvars.example terraform.tfvars   # set a globally unique bucket name
export LINODE_TOKEN="..."
terraform init && terraform apply
```

Then export the generated Object Storage keys, which the S3-compatible state
backend authenticates with:

```bash
export TF_STATE_BUCKET=$(terraform output -raw state_bucket_name)
export TF_STATE_ENDPOINT=$(terraform output -raw state_endpoint)
export AWS_ACCESS_KEY_ID=$(terraform output -raw state_access_key)
export AWS_SECRET_ACCESS_KEY=$(terraform output -raw state_secret_key)
```

**Linode has no state locking backend.** Concurrent applies against the same
tier will corrupt state. Coordinate, or apply only from CI.

### 2. Apply a tier

```bash
bin/terraform.sh apply --target=linode/small/cluster  --reactory-env=dev
bin/terraform.sh apply --target=linode/small/workload --reactory-env=dev --image-tag=1.1.0
```

### 3. Point DNS at the NodeBalancer

```bash
terraform -chdir=linode/environments/small/workload output load_balancer_ip
```

Create an A record, then set `enable_tls = true` and re-apply. cert-manager's
HTTP-01 challenge needs the name resolving first — it defaults to the Let's
Encrypt **staging** endpoint below the large tier so a misconfigured record does
not burn the production rate limit.

## How this differs from the AWS blueprints

| | AWS | Linode |
|---|---|---|
| Secrets | Secrets Manager + External Secrets Operator | Kubernetes Secrets written by Terraform |
| Ingress | AWS Load Balancer Controller + ACM | ingress-nginx + NodeBalancer + cert-manager |
| Registry | ECR, node role grants pull | GHCR, `imagePullSecrets` for private repos |
| State locking | DynamoDB | **none** |
| Kubernetes auth | `aws eks get-token`, short-lived | long-lived token from the kubeconfig |

**Secrets live in Terraform state on Linode.** There is no secrets manager to
point External Secrets Operator at, so `modules/kubernetes/app_secrets` writes
the Kubernetes Secrets directly and their values are stored in the state file.
The Object Storage bucket is therefore a secrets store: keep it private, keep
versioning on, and restrict the access key to it.

The cluster layer's state additionally holds the LKE kubeconfig, which contains
a long-lived cluster-admin token.
