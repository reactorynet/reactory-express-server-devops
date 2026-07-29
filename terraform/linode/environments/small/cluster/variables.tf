variable "project" {
  type    = string
  default = "reactory"
}

variable "tier" {
  type    = string
  default = "small"
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
  default     = "10.20.0.0/24"
}

# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------
variable "node_type" {
  description = <<-EOT
    Linode instance type. LKE rejects the 1GB Nanode, so g6-standard-1 (2GB) is
    the floor. This tier runs MongoDB, PostgreSQL, Valkey and
    Meilisearch as pods alongside the application, so 4GB is the practical
    minimum.
  EOT
  type        = string
  default     = "g6-standard-2"
}

variable "node_count" {
  type    = number
  default = 1
}

variable "autoscale" {
  type    = bool
  default = false
}

variable "min_nodes" {
  type    = number
  default = 1
}

variable "max_nodes" {
  type    = number
  default = 3
}
