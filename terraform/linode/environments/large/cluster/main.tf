# ---------------------------------------------------------------------------
# Linode / large / cluster layer
#
# The largest deployment Linode supports, with an important caveat.
#
# LINODE HAS NO MANAGED MongoDB, Redis/Valkey OR SEARCH SERVICE. Akamai's
# Managed Databases offer MySQL and PostgreSQL and nothing else. So even at this
# tier, MongoDB, Valkey and Meilisearch run as in-cluster pods on block storage:
# single instances, no managed failover, no automated backup, no point-in-time
# recovery.
#
# PostgreSQL alone gets Linode's 3-node HA configuration.
#
# If MongoDB durability matters, this tier is not equivalent to the DigitalOcean
# or AWS large tiers — DigitalOcean has managed mongodb, valkey and opensearch
# engines, and is the better choice for a production Reactory deployment.
# Alternatively point the mongo block at an external Atlas cluster.
#
# Apply order:
#   1. linode/bootstrap                          (once per account)
#   2. linode/environments/large/cluster
#   3. linode/environments/large/workload
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 4.1"
    }
  }
  required_version = ">= 1.8.0"
}

provider "linode" {}

locals {
  cluster_name = "${var.project}-${var.tier}"

  tags = [
    "project:${var.project}",
    "tier:${var.tier}",
    "managed-by:terraform",
  ]
}

module "lke" {
  source = "../../../../modules/linode/lke"

  cluster_name       = local.cluster_name
  region             = var.region
  kubernetes_version = var.kubernetes_version

  create_vpc  = true
  subnet_ipv4 = var.subnet_ipv4

  node_type  = var.node_type
  node_count = var.node_count
  autoscale  = var.autoscale
  min_nodes  = var.min_nodes
  max_nodes  = var.max_nodes

  # Irreversible on Linode — see the module documentation.
  high_availability = true

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Managed PostgreSQL — the only managed engine Linode offers that this stack uses
# ---------------------------------------------------------------------------
module "postgres" {
  source = "../../../../modules/linode/database"

  label          = "${local.cluster_name}-pg"
  engine_version = var.postgres_version
  region         = var.region
  type           = var.postgres_type
  cluster_size   = var.postgres_cluster_size

  vpc_id    = module.lke.vpc_id
  subnet_id = module.lke.subnet_id

  # Private only; the cluster reaches it over the VPC.
  public_access = false
}
