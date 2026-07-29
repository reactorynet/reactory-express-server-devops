variable "name" {
  description = "Database cluster name"
  type        = string
}

variable "engine" {
  description = "One of pg, mysql, mongodb, valkey, opensearch, kafka"
  type        = string

  validation {
    condition     = contains(["pg", "mysql", "mongodb", "valkey", "opensearch", "kafka"], var.engine)
    error_message = "engine must be one of: pg, mysql, mongodb, valkey, opensearch, kafka."
  }
}

variable "engine_version" {
  description = "Major version as a string, e.g. \"16\" for pg, \"7\" for mongodb, \"8\" for valkey"
  type        = string
}

variable "size" {
  description = <<-EOT
    Database node size slug, e.g. db-s-1vcpu-1gb (smallest), db-s-1vcpu-2gb,
    db-s-2vcpu-4gb. These are separate from Droplet slugs and priced differently.
  EOT
  type        = string
}

variable "region" {
  description = "Must match the cluster's region for the VPC to apply"
  type        = string
}

variable "node_count" {
  description = <<-EOT
    1 is a single node with no failover. 2+ adds standby nodes and roughly
    multiplies the cost — worth it only where an unplanned failover has to be
    survivable.
  EOT
  type        = number
  default     = 1
}

variable "vpc_uuid" {
  description = "VPC to attach to; must be the cluster's VPC for private traffic"
  type        = string
}

variable "allowed_kubernetes_cluster_ids" {
  description = <<-EOT
    DOKS cluster UUIDs permitted to connect. Effectively required: the managed
    database has a public endpoint, and the VPC alone does not close it.
  EOT
  type        = list(string)
  default     = []
}

variable "allowed_ip_addresses" {
  description = "Additional IPs permitted to connect, for CI or a bastion"
  type        = list(string)
  default     = []
}

variable "database_name" {
  description = "Database to create. Ignored for valkey and opensearch, which have no named databases."
  type        = string
  default     = null
}

variable "app_username" {
  description = <<-EOT
    Dedicated application user to create, so the pods do not hold the doadmin
    superuser credential. Ignored for valkey and opensearch.
  EOT
  type        = string
  default     = null
}

variable "eviction_policy" {
  description = "Valkey only: what to evict at maxmemory"
  type        = string
  default     = "allkeys_lru"
}

variable "maintenance_day" {
  type    = string
  default = "sunday"
}

variable "maintenance_hour" {
  type    = string
  default = "04:00:00"
}

variable "tags" {
  type    = list(string)
  default = []
}
