# ---------------------------------------------------------------------------
# staging / cluster layer
#
# A genuine pre-production rehearsal: the same managed services as production —
# DocumentDB, Aurora PostgreSQL Serverless v2, ElastiCache Valkey, OpenSearch —
# at the smallest sizing that still exercises them.
#
# Deliberately the same as production:
#   - managed services rather than in-cluster pods, so TLS requirements,
#     connection strings and failover semantics match
#   - two AZs, so topology spread and zone-aware storage behave the same
#   - OpenSearch rather than Meilisearch, so the search provider path is the one
#     production runs
#
# Deliberately different from production:
#   - one instance per data service instead of two
#   - deletion protection off and final snapshots skipped, so the environment can
#     be torn down and rebuilt without manual intervention
#   - shorter backup retention
#
# Apply order:
#   1. aws/bootstrap                (once per account)
#   2. environments/staging/cluster
#   3. environments/staging/workload
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
  required_version = ">= 1.8.0"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  cluster_name = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Layer       = "cluster"
  }
}

# ---------------------------------------------------------------------------
# Network — both AZs, but a single NAT gateway. Staging rehearses multi-AZ
# scheduling and storage; paying for a second NAT gateway to rehearse NAT
# redundancy is not worth the standing cost.
# ---------------------------------------------------------------------------
module "vpc" {
  source = "../../../modules/vpc"

  cluster_name         = local.cluster_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = true

  tags = local.common_tags
}

module "eks" {
  source = "../../../modules/eks"

  cluster_name        = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_api_endpoint = var.public_api_endpoint
  api_allowed_cidrs   = var.api_allowed_cidrs

  # ON_DEMAND rather than SPOT: a node interruption mid-test is noise that makes
  # staging results hard to trust.
  node_instance_types = var.node_instance_types
  node_capacity_type  = "ON_DEMAND"
  node_desired_count  = var.node_desired_count
  node_min_count      = 2
  node_max_count      = var.node_max_count
  node_disk_size_gb   = 40

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Managed data services
# ---------------------------------------------------------------------------
module "documentdb" {
  source = "../../../modules/documentdb"

  cluster_name          = local.cluster_name
  vpc_id                = module.vpc.vpc_id
  vpc_cidr              = module.vpc.vpc_cidr
  private_subnet_ids    = module.vpc.private_subnet_ids
  master_username       = var.mongo_username
  master_password       = var.mongo_password
  instance_class        = var.docdb_instance_class
  instance_count        = 1
  backup_retention_days = 3

  # Staging must be disposable.
  deletion_protection = false
  skip_final_snapshot = true

  tags = local.common_tags
}

module "rds" {
  source = "../../../modules/rds"

  cluster_name            = local.cluster_name
  vpc_id                  = module.vpc.vpc_id
  vpc_cidr                = module.vpc.vpc_cidr
  private_subnet_ids      = module.vpc.private_subnet_ids
  database_name           = var.postgres_database
  master_username         = var.postgres_username
  master_password         = var.postgres_password
  serverless_min_capacity = 0.5
  serverless_max_capacity = var.rds_max_capacity
  instance_count          = 1

  deletion_protection = false
  skip_final_snapshot = true

  tags = local.common_tags
}

module "valkey" {
  source = "../../../modules/elasticache_valkey"

  cluster_name       = local.cluster_name
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
  mode               = "single"
  node_type          = var.valkey_node_type
  auth_token         = var.valkey_auth_token

  # No Multi-AZ failover in staging; transit encryption and the AUTH token — the
  # parts applications actually have to cope with — are on regardless.
  multi_az                = false
  snapshot_retention_days = 1

  tags = local.common_tags
}

module "opensearch" {
  source = "../../../modules/opensearch"

  cluster_name       = local.cluster_name
  mode               = "managed"
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
  instance_type      = var.opensearch_instance_type
  instance_count     = 1
  volume_size_gb     = var.opensearch_volume_size_gb
  master_username    = var.opensearch_username
  master_password    = var.opensearch_password

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Secrets
# ---------------------------------------------------------------------------
module "secrets_manager" {
  source = "../../../modules/secrets_manager"

  cluster_name         = local.cluster_name
  secret_prefix        = "${var.project}/${var.environment}"
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  recovery_window_days = 0

  # Same set as production — OpenSearch, no Meilisearch.
  enabled_secrets = ["mongo", "postgres", "valkey", "opensearch", "grafana", "app"]

  mongo_username         = var.mongo_username
  mongo_password         = var.mongo_password
  postgres_username      = var.postgres_username
  postgres_password      = var.postgres_password
  valkey_auth_token      = var.valkey_auth_token
  opensearch_username    = var.opensearch_username
  opensearch_password    = var.opensearch_password
  grafana_admin_password = var.grafana_admin_password
  app_secret_key         = var.app_secret_key

  tags = local.common_tags
}
