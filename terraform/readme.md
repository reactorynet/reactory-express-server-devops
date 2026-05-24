# Reactory Terraform

Infrastructure-as-code for deploying the Reactory platform on AWS and locally via Kubernetes. All configuration is managed with Terraform >= 1.8.0.

## Structure

```
terraform/
  aws/
    state_bootstrap/          # One-time setup: S3 state bucket + DynamoDB lock table
    modules/                  # Shared modules consumed by all blueprints
      vpc/                    # VPC, subnets, NAT gateways, route tables
      eks/                    # EKS cluster, node groups, IRSA OIDC provider, add-ons
      ecr/                    # ECR repositories for express-server and pwa-client
      rds/                    # Aurora PostgreSQL Serverless v2
      documentdb/             # Amazon DocumentDB (MongoDB-compatible)
      elasticache_valkey/     # ElastiCache for Valkey (Redis-compatible cache)
      opensearch/             # Amazon OpenSearch Service (managed or serverless)
      meilisearch/            # Self-hosted Meilisearch on EKS (dev/staging)
      secrets/                # AWS Secrets Manager + External Secrets Operator
      alb_ingress/            # AWS Load Balancer Controller + ACM
      observability/          # kube-prometheus-stack (Prometheus, Grafana) + Jaeger
    dev-single-az/            # Blueprint: low-cost developer environment
    production-single-region/ # Blueprint: HA production environment
  minikube/                   # Local development via minikube
```

## Blueprints

### `dev-single-az`
Low-cost environment for development and testing.

| Component | Implementation |
|-----------|---------------|
| Compute | EKS SPOT nodes (t3.medium/large), single AZ |
| Networking | Single NAT gateway |
| MongoDB | Self-hosted pod + gp3 EBS PVC |
| PostgreSQL | Self-hosted pod + gp3 EBS PVC |
| Cache | ElastiCache Valkey `single` node |
| Search | Self-hosted Meilisearch pod |
| TLS | Optional (enabled when `domain_name` is set) |

### `production-single-region`
High-availability environment in a single AWS region (both `us-west-1` AZs by default).

| Component | Implementation |
|-----------|---------------|
| Compute | EKS ON_DEMAND nodes (m6a/m6i.large), 2 AZs, HPA |
| Networking | One NAT gateway per AZ |
| MongoDB | Amazon DocumentDB (2-instance, deletion protection) |
| PostgreSQL | Aurora PostgreSQL Serverless v2 (writer + reader) |
| Cache | ElastiCache Valkey with Multi-AZ auto-failover |
| Search | Amazon OpenSearch Service (2-node, AZ-aware) |
| TLS | ACM certificate, HTTPS enforced, 80 → 443 redirect |

## Getting Started

### 1. Bootstrap remote state (once per account)

```bash
cd aws/state_bootstrap
terraform init
terraform apply
```

Note the `state_bucket_name` output and update `bucket` in each blueprint's `backend.tf`.

### 2. Initialise a blueprint

```bash
cd aws/dev-single-az          # or production-single-region
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with non-secret values
terraform init
```

### 3. Supply secrets

Never put secrets in `terraform.tfvars`. Use environment variables instead:

```bash
export TF_VAR_mongo_username="..."
export TF_VAR_mongo_password="..."
export TF_VAR_postgres_username="..."
export TF_VAR_postgres_password="..."
export TF_VAR_valkey_auth_token="..."      # min 16 characters
export TF_VAR_meilisearch_master_key="..." # dev only
export TF_VAR_opensearch_password="..."   # prod only
export TF_VAR_grafana_admin_password="..."
export TF_VAR_app_secret_key="..."
```

### 4. Deploy

```bash
terraform plan
terraform apply
```

### 5. Update kubeconfig

```bash
$(terraform output -raw kubeconfig_command)
```

## Push container images

After the ECR repositories are created, tag and push your images:

```bash
REGION=us-west-1
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

aws ecr get-login-password --region $REGION \
  | docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com

docker tag reactory/express-server:1.1.0 $(terraform output -raw ecr_express_server_url):1.1.0
docker push $(terraform output -raw ecr_express_server_url):1.1.0

docker tag reactory/pwa-client:1.1.0 $(terraform output -raw ecr_pwa_client_url):1.1.0
docker push $(terraform output -raw ecr_pwa_client_url):1.1.0
```

Then re-run `terraform apply -var image_tag=1.1.0` to roll out the new images.

## Region notes

`us-west-1` has only two availability zones (`us-west-1a`, `us-west-1c`). All default CIDR and AZ lists are sized accordingly. To deploy in a 3-AZ region (e.g. `us-west-2`, `us-east-1`), override `availability_zones`, `public_subnet_cidrs`, and `private_subnet_cidrs` in `terraform.tfvars`.

## Local development

See `minikube/` for a self-contained local setup using minikube. It does not require AWS credentials and is intended for offline development only.
