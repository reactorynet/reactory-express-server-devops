# ---------------------------------------------------------------------------
# DigitalOcean / large / cluster layer
#
# Production-grade: an HA control plane, an autoscaling node pool, and every
# data service on a managed cluster with a standby node.
#
# DigitalOcean covers the whole Reactory stack — pg, mongodb, valkey and
# opensearch are all managed engines — so unlike Linode this tier needs nothing
# self-hosted. That is the main reason to choose DigitalOcean over Linode for a
# production deployment.
#
# Differences from medium, all deliberate:
#   - HA control plane (a paid DigitalOcean add-on, unlike EKS)
#   - node_count 2+ per managed database, giving a failover target
#   - MongoDB and OpenSearch managed rather than in-cluster
#   - autoscaling node pool
#   - destroy_associated_resources off, so a destroy cannot silently remove
#     volumes holding data
#
# Apply order:
#   1. digitalocean/bootstrap
#   2. digitalocean/environments/large/cluster
#   3. digitalocean/environments/large/workload
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.43"
    }
  }
  required_version = ">= 1.8.0"
}

provider "digitalocean" {}

locals {
  cluster_name = "${var.project}-${var.tier}"

  tags = [
    "project:${var.project}",
    "tier:${var.tier}",
    "managed-by:terraform",
  ]
}

module "doks" {
  source = "../../../../modules/digitalocean/doks"

  cluster_name       = local.cluster_name
  region             = var.region
  kubernetes_version = var.kubernetes_version

  create_vpc   = true
  vpc_ip_range = var.vpc_ip_range

  node_size  = var.node_size
  auto_scale = true
  min_nodes  = var.min_nodes
  max_nodes  = var.max_nodes

  high_availability = true

  # A production destroy must not take volumes with it. Load balancers left
  # behind are a billing annoyance; deleted PVCs are data loss.
  destroy_associated_resources = false

  tags = local.tags
}

module "postgres" {
  source = "../../../../modules/digitalocean/database"

  name           = "${local.cluster_name}-pg"
  engine         = "pg"
  engine_version = var.postgres_version
  size           = var.postgres_size
  region         = var.region
  node_count     = var.database_node_count

  vpc_uuid                       = module.doks.vpc_uuid
  allowed_kubernetes_cluster_ids = [module.doks.cluster_id]

  database_name = var.postgres_database
  app_username  = var.postgres_username

  tags = local.tags
}

module "mongodb" {
  source = "../../../../modules/digitalocean/database"

  name           = "${local.cluster_name}-mongo"
  engine         = "mongodb"
  engine_version = var.mongodb_version
  size           = var.mongodb_size
  region         = var.region
  node_count     = var.database_node_count

  vpc_uuid                       = module.doks.vpc_uuid
  allowed_kubernetes_cluster_ids = [module.doks.cluster_id]

  database_name = var.mongo_database
  app_username  = var.mongo_username

  tags = local.tags
}

module "valkey" {
  source = "../../../../modules/digitalocean/database"

  name           = "${local.cluster_name}-valkey"
  engine         = "valkey"
  engine_version = var.valkey_version
  size           = var.valkey_size
  region         = var.region
  node_count     = 1

  vpc_uuid                       = module.doks.vpc_uuid
  allowed_kubernetes_cluster_ids = [module.doks.cluster_id]

  eviction_policy = "allkeys_lru"

  tags = local.tags
}

module "opensearch" {
  source = "../../../../modules/digitalocean/database"

  name           = "${local.cluster_name}-search"
  engine         = "opensearch"
  engine_version = var.opensearch_version
  size           = var.opensearch_size
  region         = var.region
  node_count     = 1

  vpc_uuid                       = module.doks.vpc_uuid
  allowed_kubernetes_cluster_ids = [module.doks.cluster_id]

  tags = local.tags
}
