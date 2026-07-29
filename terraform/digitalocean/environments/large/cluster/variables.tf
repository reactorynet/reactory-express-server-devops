variable "project" {
  type    = string
  default = "reactory"
}

variable "tier" {
  type    = string
  default = "large"
}

variable "region" {
  type    = string
  default = "nyc3"
}

variable "kubernetes_version" {
  description = "Exact DOKS version slug. Rehearse every change in medium first."
  type        = string
  default     = "1.31.1-do.0"
}

variable "vpc_ip_range" {
  description = "Distinct from small (10.10) and medium (10.11)"
  type        = string
  default     = "10.12.0.0/16"
}

# ---------------------------------------------------------------------------
# Nodes — autoscaling; no data services share the node pool at this tier
# ---------------------------------------------------------------------------
variable "node_size" {
  type    = string
  default = "s-4vcpu-8gb"
}

variable "min_nodes" {
  type    = number
  default = 3
}

variable "max_nodes" {
  description = "Ceiling for the autoscaler. Keep above what the HPA maxima can demand."
  type        = number
  default     = 8
}

# ---------------------------------------------------------------------------
# Managed data services
# ---------------------------------------------------------------------------
variable "database_node_count" {
  description = <<-EOT
    Nodes per managed PostgreSQL and MongoDB cluster. 2 adds a standby and a
    failover target, and roughly doubles the cost of each.
  EOT
  type        = number
  default     = 2
}

variable "postgres_version" {
  type    = string
  default = "16"
}

variable "postgres_size" {
  type    = string
  default = "db-s-2vcpu-4gb"
}

variable "postgres_database" {
  type    = string
  default = "reactory"
}

variable "postgres_username" {
  type    = string
  default = "reactory"
}

variable "mongodb_version" {
  type    = string
  default = "7"
}

variable "mongodb_size" {
  type    = string
  default = "db-s-2vcpu-4gb"
}

variable "mongo_database" {
  type    = string
  default = "reactory"
}

variable "mongo_username" {
  type    = string
  default = "reactory"
}

variable "valkey_version" {
  type    = string
  default = "8"
}

variable "valkey_size" {
  type    = string
  default = "db-s-1vcpu-2gb"
}

variable "opensearch_version" {
  type    = string
  default = "2"
}

variable "opensearch_size" {
  type    = string
  default = "db-s-2vcpu-4gb"
}
