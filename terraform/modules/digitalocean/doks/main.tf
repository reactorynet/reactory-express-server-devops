# ---------------------------------------------------------------------------
# module: doks
#
# A DigitalOcean Kubernetes cluster with its VPC and a default node pool.
#
# The DOKS control plane is free — you pay only for worker Droplets and any load
# balancer — which is why even the small tier can afford to be a real cluster
# rather than a single Droplet running compose.
#
# High availability is a paid control-plane add-on here, unlike EKS where it is
# implicit. It is off for small and medium and on for large.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.43"
    }
  }
}

resource "digitalocean_vpc" "this" {
  count = var.create_vpc ? 1 : 0

  name     = "${var.cluster_name}-vpc"
  region   = var.region
  ip_range = var.vpc_ip_range

  description = "Private network for the ${var.cluster_name} cluster and its managed databases"
}

locals {
  vpc_uuid = var.create_vpc ? digitalocean_vpc.this[0].id : var.vpc_uuid
}

resource "digitalocean_kubernetes_cluster" "this" {
  name     = var.cluster_name
  region   = var.region
  version  = var.kubernetes_version
  vpc_uuid = local.vpc_uuid

  # Paid add-on. Worth it only where control-plane downtime during an upgrade
  # would matter.
  ha = var.high_availability

  # Surge upgrades add a node before draining one, so a rollout does not shrink
  # capacity. Free, and there is no reason to disable it.
  surge_upgrade = true
  auto_upgrade  = var.auto_upgrade

  # DOKS deletes its load balancers and volumes with the cluster only when asked.
  # Without this a destroy leaves the ingress load balancer behind, still billing.
  destroy_all_associated_resources = var.destroy_associated_resources

  # Images come from GHCR, not DOCR, so the registry integration is unnecessary.
  registry_integration = var.registry_integration

  maintenance_policy {
    day        = var.maintenance_day
    start_time = var.maintenance_start_time
  }

  node_pool {
    name       = "${var.cluster_name}-default"
    size       = var.node_size
    node_count = var.auto_scale ? null : var.node_count
    auto_scale = var.auto_scale
    min_nodes  = var.auto_scale ? var.min_nodes : null
    max_nodes  = var.auto_scale ? var.max_nodes : null

    labels = var.node_labels
  }

  tags = var.tags
}
