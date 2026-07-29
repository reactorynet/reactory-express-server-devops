variable "project" {
  type    = string
  default = "reactory"
}

variable "tier" {
  type    = string
  default = "large"
}

variable "region" {
  description = "Linode region id, e.g. us-ord, eu-west, ap-south"
  type        = string
  default     = "us-ord"
}

variable "kubernetes_version" {
  description = "LKE version in major.minor form; Linode manages the patch level"
  type        = string
  default     = "1.31"
}

variable "subnet_ipv4" {
  description = "VPC subnet CIDR. Distinct per tier so they can coexist or be peered."
  type        = string
  default     = "10.22.0.0/24"
}

# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------
variable "node_type" {
  description = <<-EOT
    Linode instance type. LKE rejects the 1GB Nanode, so g6-standard-1 (2GB) is
    the floor. MongoDB, Valkey and Meilisearch still run as pods even at this
    tier, because Linode has no managed equivalent — size accordingly.
  EOT
  type        = string
  default     = "g6-standard-4"
}

variable "node_count" {
  type    = number
  default = 3
}

variable "autoscale" {
  type    = bool
  default = true
}

variable "min_nodes" {
  type    = number
  default = 3
}

variable "max_nodes" {
  type    = number
  default = 8
}

# ---------------------------------------------------------------------------
# Managed PostgreSQL
# ---------------------------------------------------------------------------
variable "postgres_version" {
  type    = string
  default = "16"
}

variable "postgres_type" {
  description = "Managed Databases accept the Nanode, unlike LKE"
  type        = string
  default     = "g6-standard-2"
}

variable "postgres_cluster_size" {
  description = <<-EOT
    1 or 3 — Linode offers no 2-node option, so HA roughly triples the cost.
  EOT
  type        = number
  default     = 3
}
