# ---------------------------------------------------------------------------
# DigitalOcean / small / cluster layer
#
# The cheapest thing that is still a real Kubernetes cluster: one VPC, one DOKS
# cluster, one node, and no managed databases at all.
#
# Intended for quick throwaway testing. Every data service runs as a pod in the
# workload layer, so the only standing costs are the worker node and the load
# balancer the ingress controller creates — the DOKS control plane is free.
#
# What this tier gives up, deliberately:
#   - no managed database, so no backups, no failover, no point-in-time recovery
#   - one node, so any node event is full downtime
#   - no HA control plane (a paid add-on on DigitalOcean)
#   - data lives on PVCs that a cluster destroy will remove
#
# It is nonetheless the same code path as large: identical modules, identical
# application contract, only the wiring differs.
#
# Apply order:
#   1. digitalocean/bootstrap                       (once per account)
#   2. digitalocean/environments/small/cluster
#   3. digitalocean/environments/small/workload
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

provider "digitalocean" {
  # Reads DIGITALOCEAN_TOKEN from the environment.
}

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
  node_count = var.node_count
  auto_scale = false

  # Paid add-on, and pointless on a single-node throwaway cluster.
  high_availability = false

  # A destroy should leave nothing billing behind on a disposable tier.
  destroy_associated_resources = true

  tags = local.tags
}
