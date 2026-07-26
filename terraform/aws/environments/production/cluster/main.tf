# ---------------------------------------------------------------------------
# production / cluster layer
#
# High availability within a single region, across both us-west-1 AZs.
#
# Differences from staging, all of them deliberate:
#   - one NAT gateway per AZ, so losing an AZ does not sever egress
#   - two instances per data service, giving DocumentDB and Aurora a failover
#     target and OpenSearch zone awareness
#   - ElastiCache Multi-AZ with automatic failover
#   - deletion protection on and final snapshots taken, so no single apply can
#     destroy production data
#   - longer backup retention
#
# Apply order:
#   1. aws/bootstrap                   (once per account)
#   2. environments/production/cluster
#   3. environments/production/workload
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
# Network — one NAT gateway per AZ
# ---------------------------------------------------------------------------
module "vpc" {
  source = "../../../modules/vpc"

  cluster_name         = local.cluster_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = false

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

  node_instance_types = var.node_instance_types
  node_capacity_type  = "ON_DEMAND"
  node_desired_count  = var.node_desired_count
  node_min_count      = var.node_min_count
  node_max_count      = var.node_max_count
  node_disk_size_gb   = 50

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
  instance_count        = 2 # primary + reader
  backup_retention_days = var.backup_retention_days

  deletion_protection = true
  skip_final_snapshot = false

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
  serverless_min_capacity = var.rds_min_capacity
  serverless_max_capacity = var.rds_max_capacity
  instance_count          = 2 # writer + reader

  deletion_protection = true
  skip_final_snapshot = false

  tags = local.common_tags
}

module "valkey" {
  source = "../../../modules/elasticache_valkey"

  cluster_name            = local.cluster_name
  vpc_id                  = module.vpc.vpc_id
  vpc_cidr                = module.vpc.vpc_cidr
  private_subnet_ids      = module.vpc.private_subnet_ids
  mode                    = "single"
  node_type               = var.valkey_node_type
  auth_token              = var.valkey_auth_token
  multi_az                = true
  snapshot_retention_days = 7

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
  instance_count     = 2 # one node per AZ, zone-aware
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

  cluster_name      = local.cluster_name
  secret_prefix     = "${var.project}/${var.environment}"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  # A recovery window means a deleted secret can be restored. Never 0 here.
  recovery_window_days = var.secret_recovery_window_days

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
