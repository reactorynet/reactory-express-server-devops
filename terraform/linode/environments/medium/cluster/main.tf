# ---------------------------------------------------------------------------
# Linode / medium / cluster layer
#
# A QA environment: two nodes and a managed PostgreSQL cluster.
#
# PostgreSQL is managed because it is the one service where Linode's managed
# offering changes how the application connects — TLS is enforced and the
# credential is generated rather than supplied. MongoDB, Valkey and Meilisearch
# stay in-cluster because Linode has no managed equivalent for any of them.
#
# Apply order:
#   1. linode/bootstrap                          (once per account)
#   2. linode/environments/medium/cluster
#   3. linode/environments/medium/workload
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
  high_availability = false

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
