variable "cluster_name" {
  description = "LKE cluster label"
  type        = string
}

variable "region" {
  description = "Linode region id, e.g. us-ord, eu-west, ap-south"
  type        = string
}

variable "kubernetes_version" {
  description = <<-EOT
    LKE version in major.minor form, e.g. "1.31". Unlike DOKS these are not
    exact patch slugs — Linode manages the patch level.
  EOT
  type        = string
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
variable "create_vpc" {
  type    = bool
  default = true
}

variable "vpc_id" {
  description = "Existing VPC id when create_vpc is false"
  type        = number
  default     = null
}

variable "subnet_id" {
  description = "Existing subnet id when create_vpc is false"
  type        = number
  default     = null
}

variable "subnet_ipv4" {
  description = "CIDR for the created subnet. Managed databases join the same VPC."
  type        = string
  default     = "10.20.0.0/24"
}

# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------
variable "node_type" {
  description = <<-EOT
    Linode instance type, e.g. g6-standard-1 (2GB), g6-standard-2 (4GB),
    g6-standard-4 (8GB). LKE does not accept the 1GB Nanode, so g6-standard-1 is
    the floor.
  EOT
  type        = string
}

variable "node_count" {
  description = "Fixed node count; ignored when autoscale is true"
  type        = number
  default     = 1
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

# ---------------------------------------------------------------------------
# Control plane
# ---------------------------------------------------------------------------
variable "high_availability" {
  description = <<-EOT
    Highly available control plane. Billed hourly, and IRREVERSIBLE — Linode
    provides no way to turn it back off, so setting this false again forces the
    cluster to be replaced. Enable only at a tier you intend to keep.
  EOT
  type        = bool
  default     = false
}

variable "tags" {
  type    = list(string)
  default = []
}
