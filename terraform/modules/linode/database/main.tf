# ---------------------------------------------------------------------------
# module: database
#
# A Linode Managed Database, attached to the cluster's VPC.
#
# PostgreSQL only. Akamai's Linode Managed Databases offer MySQL and PostgreSQL
# and nothing else — the MongoDB and Redis engines announced at launch were beta
# and have since been withdrawn, and there has never been a managed search
# service. Verified against the provider: database_mysql_v2 and
# database_postgresql_v2 exist; database_mongodb and database_redis do not.
#
# The practical consequence is that a Linode deployment must run MongoDB, Valkey
# and search as in-cluster pods at every tier, including large. That is the main
# thing separating a large Linode deployment from the DigitalOcean or AWS
# equivalent, and it is a real limitation rather than a configuration choice —
# see the linode readme.
#
# Unlike DigitalOcean, credentials are a generated root account rather than a
# separate application user; Linode Managed Databases expose no user management
# through the provider.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 4.1"
    }
  }
}

resource "linode_database_postgresql_v2" "this" {
  label     = var.label
  engine_id = "postgresql/${var.engine_version}"
  region    = var.region
  type      = var.type

  # 1 is a single node with no failover. 3 is Linode's HA configuration; there
  # is no 2-node option.
  cluster_size = var.cluster_size

  # private_network and updates are ATTRIBUTES in provider 4.x, not blocks.
  #
  # Restricting to the VPC subnet is what keeps this database off the public
  # internet. With public_access true the allow_list becomes the only boundary,
  # and an allow-list does not compose with an autoscaling node pool whose IPs
  # change — which is why this defaults to VPC-only.
  private_network = {
    vpc_id        = var.vpc_id
    subnet_id     = var.subnet_id
    public_access = var.public_access
  }

  # Only consulted when public_access is true.
  allow_list = var.allow_list

  updates = {
    day_of_week = var.maintenance_day
    hour_of_day = var.maintenance_hour
    duration    = 3
    frequency   = "weekly"
  }
}
