# ---------------------------------------------------------------------------
# module: lke
#
# A Linode Kubernetes Engine cluster with a VPC and one node pool.
#
# Like DOKS, the LKE control plane is free — you pay for worker Linodes and the
# NodeBalancer the ingress controller creates.
#
# Two Linode-specific behaviours worth knowing:
#
#   high_availability is IRREVERSIBLE. Once a control plane is made highly
#   available it cannot be made single again; changing the flag back forces the
#   cluster to be replaced. It is also billed hourly.
#
#   VPC support for LKE and private networking for Managed Databases only
#   arrived in provider 4.x — 2.x has neither, and the database is then reachable
#   only over its public endpoint behind an IP allow-list, which does not compose
#   with a Kubernetes node pool whose IPs change. Hence the ~> 4.1 pin.
#
#   The kubeconfig is exposed as one base64-encoded YAML blob rather than
#   discrete host/CA/token attributes, so callers decode and parse it. The token
#   inside is a long-lived service account token, not a short-lived credential
#   like DigitalOcean's — convenient, but it means the kubeconfig in state is a
#   durable cluster-admin credential.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 4.1"
    }
  }
}

resource "linode_vpc" "this" {
  count = var.create_vpc ? 1 : 0

  label       = "${var.cluster_name}-vpc"
  region      = var.region
  description = "Private network for the ${var.cluster_name} cluster and its managed databases"
}

resource "linode_vpc_subnet" "this" {
  count = var.create_vpc ? 1 : 0

  vpc_id = linode_vpc.this[0].id
  label  = "${var.cluster_name}-subnet"
  ipv4   = var.subnet_ipv4
}

locals {
  vpc_id    = var.create_vpc ? linode_vpc.this[0].id : var.vpc_id
  subnet_id = var.create_vpc ? linode_vpc_subnet.this[0].id : var.subnet_id
}

resource "linode_lke_cluster" "this" {
  label       = var.cluster_name
  k8s_version = var.kubernetes_version
  region      = var.region
  tags        = var.tags

  vpc_id    = local.vpc_id
  subnet_id = local.subnet_id

  control_plane {
    # Irreversible: enabling HA cannot be undone, and turning this back off
    # forces cluster replacement.
    high_availability = var.high_availability
  }

  pool {
    type  = var.node_type
    count = var.autoscale ? null : var.node_count

    # Encrypts the node's local disk. No cost, no downside.
    disk_encryption = "enabled"

    dynamic "autoscaler" {
      for_each = var.autoscale ? [1] : []
      content {
        min = var.min_nodes
        max = var.max_nodes
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Decode the kubeconfig so callers get discrete endpoint, CA and token values
# rather than having to parse the blob themselves.
# ---------------------------------------------------------------------------
locals {
  kubeconfig = yamldecode(base64decode(linode_lke_cluster.this.kubeconfig))

  cluster_endpoint       = local.kubeconfig["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = local.kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"]
  cluster_token          = local.kubeconfig["users"][0]["user"]["token"]
}
