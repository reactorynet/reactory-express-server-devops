# ---------------------------------------------------------------------------
# dev / cluster layer
#
# Everything AWS-side for the dev environment: network, EKS, the managed cache,
# and the Secrets Manager entries. No Kubernetes objects — those are the workload
# layer, which reads this layer's state.
#
# Apply order:
#   1. aws/bootstrap          (once per account)
#   2. environments/dev/cluster
#   3. environments/dev/workload
#
# Dev keeps MongoDB and PostgreSQL as in-cluster pods on EBS rather than
# DocumentDB and Aurora, which is the bulk of the cost difference against
# staging. Those pods are defined in the workload layer.
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
# Network — single AZ, single NAT gateway. A NAT gateway is billed hourly per
# AZ, so this is the largest standing saving available in a dev environment.
# ---------------------------------------------------------------------------
module "vpc" {
  source = "../../../modules/vpc"

  cluster_name         = local.cluster_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = [var.availability_zones[0]]
  public_subnet_cidrs  = [var.public_subnet_cidrs[0]]
  private_subnet_cidrs = [var.private_subnet_cidrs[0]]
  single_nat_gateway   = true

  tags = local.common_tags
}

module "eks" {
  source = "../../../modules/eks"

  cluster_name        = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_api_endpoint = true
  api_allowed_cidrs   = var.api_allowed_cidrs

  node_instance_types = var.node_instance_types
  node_capacity_type  = "SPOT"
  node_desired_count  = var.node_desired_count
  node_min_count      = 1
  node_max_count      = var.node_max_count
  node_disk_size_gb   = 30

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Valkey — managed even in dev, because ElastiCache behaviour (TLS with an AUTH
# token, failover semantics) differs enough from a Redis pod that testing
# against a pod hides real problems.
# ---------------------------------------------------------------------------
module "valkey" {
  source = "../../../modules/elasticache_valkey"

  cluster_name            = local.cluster_name
  vpc_id                  = module.vpc.vpc_id
  vpc_cidr                = module.vpc.vpc_cidr
  private_subnet_ids      = module.vpc.private_subnet_ids
  mode                    = "single"
  node_type               = var.valkey_node_type
  auth_token              = var.valkey_auth_token
  multi_az                = false
  snapshot_retention_days = 0

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Secrets — created here so the credentials shared with the data services above
# are defined exactly once. The workload layer projects them into the cluster.
# ---------------------------------------------------------------------------
module "secrets_manager" {
  source = "../../../modules/secrets_manager"

  cluster_name      = local.cluster_name
  secret_prefix     = "${var.project}/${var.environment}"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  # Immediate deletion so a torn-down dev environment can be recreated under the
  # same secret names without waiting out a recovery window.
  recovery_window_days = 0

  # Self-hosted Mongo/Postgres and Meilisearch; no OpenSearch in dev.
  enabled_secrets = ["mongo", "postgres", "valkey", "meili", "grafana", "app"]

  mongo_username         = var.mongo_username
  mongo_password         = var.mongo_password
  postgres_username      = var.postgres_username
  postgres_password      = var.postgres_password
  valkey_auth_token      = var.valkey_auth_token
  meilisearch_master_key = var.meilisearch_master_key
  grafana_admin_password = var.grafana_admin_password
  app_secret_key         = var.app_secret_key

  tags = local.common_tags
}
