# ---------------------------------------------------------------------------
# Linode / small / cluster layer
#
# The cheapest thing that is still a real Kubernetes cluster: one VPC, one LKE
# cluster, one node, and no managed databases.
#
# Every data service runs as a pod in the workload layer, so the only standing
# costs are the worker Linode and the NodeBalancer the ingress controller
# creates — the LKE control plane is free.
#
# Apply order:
#   1. linode/bootstrap                          (once per account)
#   2. linode/environments/small/cluster
#   3. linode/environments/small/workload
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
