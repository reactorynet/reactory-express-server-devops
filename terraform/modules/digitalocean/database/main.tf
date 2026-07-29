# ---------------------------------------------------------------------------
# module: database
#
# One DigitalOcean managed database cluster, restricted to a DOKS cluster.
#
# Wraps every engine the Reactory stack needs — pg, mongodb, valkey, opensearch —
# behind one interface, so a tier turns a service managed or self-hosted by
# adding or removing a module block rather than rewriting it.
#
# Access control is a database firewall rule of type "k8s" holding the cluster
# UUID. That is the whole boundary: DigitalOcean managed databases have a public
# endpoint by default, and joining the VPC alone does not close it. Without the
# firewall the database is reachable from the internet with only a password in
# front of it.
#
# TLS is mandatory and not negotiable on DigitalOcean managed databases. The
# caller must set the corresponding tls flag on reactory_app.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.43"
    }
  }
}

locals {
  # Engines that carry named databases and users. Valkey is a key-value store
  # with a single implicit namespace, so it has neither.
  supports_db_and_users = contains(["pg", "mysql", "mongodb"], var.engine)
}

resource "digitalocean_database_cluster" "this" {
  name       = var.name
  engine     = var.engine
  version    = var.engine_version
  size       = var.size
  region     = var.region
  node_count = var.node_count

  # Placing the cluster in the DOKS VPC keeps traffic on the private network and
  # off the public endpoint.
  private_network_uuid = var.vpc_uuid

  # Valkey only; ignored by the other engines.
  eviction_policy = var.engine == "valkey" ? var.eviction_policy : null

  tags = var.tags

  maintenance_window {
    day  = var.maintenance_day
    hour = var.maintenance_hour
  }
}

# ---------------------------------------------------------------------------
# Firewall — the only thing standing between the public endpoint and the world
# ---------------------------------------------------------------------------
resource "digitalocean_database_firewall" "this" {
  cluster_id = digitalocean_database_cluster.this.id

  dynamic "rule" {
    for_each = var.allowed_kubernetes_cluster_ids
    content {
      type  = "k8s"
      value = rule.value
    }
  }

  # Escape hatch for a CI runner or a bastion that needs direct access.
  dynamic "rule" {
    for_each = var.allowed_ip_addresses
    content {
      type  = "ip_addr"
      value = rule.value
    }
  }
}

resource "digitalocean_database_db" "this" {
  count = local.supports_db_and_users && var.database_name != null ? 1 : 0

  cluster_id = digitalocean_database_cluster.this.id
  name       = var.database_name
}

# ---------------------------------------------------------------------------
# Application user
#
# The cluster is created with a `doadmin` superuser. Creating a dedicated
# application user means the credential the pods hold is not the superuser, and
# can be rotated independently.
# ---------------------------------------------------------------------------
resource "digitalocean_database_user" "app" {
  count = local.supports_db_and_users && var.app_username != null ? 1 : 0

  cluster_id = digitalocean_database_cluster.this.id
  name       = var.app_username
}
