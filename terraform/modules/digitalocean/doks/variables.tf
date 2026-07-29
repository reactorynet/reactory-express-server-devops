variable "cluster_name" {
  type = string
}

variable "region" {
  description = "DigitalOcean region slug, e.g. nyc3, lon1, fra1"
  type        = string
}

variable "kubernetes_version" {
  description = <<-EOT
    DOKS version slug, e.g. "1.31.1-do.0". Unlike EKS these are exact patch
    slugs and are retired regularly; `doctl kubernetes options versions` lists
    what is currently available.
  EOT
  type        = string
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
variable "create_vpc" {
  description = "Create a dedicated VPC. Set false to place the cluster in an existing one."
  type        = bool
  default     = true
}

variable "vpc_uuid" {
  description = "Existing VPC to use when create_vpc is false"
  type        = string
  default     = null
}

variable "vpc_ip_range" {
  description = "CIDR for the created VPC. Must not overlap other VPCs you intend to peer."
  type        = string
  default     = "10.10.0.0/16"
}

# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------
variable "node_size" {
  description = <<-EOT
    Droplet size slug for worker nodes, e.g. s-2vcpu-2gb, s-2vcpu-4gb,
    s-4vcpu-8gb. DOKS reserves roughly 20% of a node for system components, so
    a 2GB node has well under 2GB allocatable.
  EOT
  type        = string
}

variable "node_count" {
  description = "Fixed node count; ignored when auto_scale is true"
  type        = number
  default     = 1
}

variable "auto_scale" {
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

variable "node_labels" {
  type    = map(string)
  default = {}
}

# ---------------------------------------------------------------------------
# Control plane
# ---------------------------------------------------------------------------
variable "high_availability" {
  description = <<-EOT
    Highly available control plane. This is a PAID add-on on DigitalOcean —
    roughly $40/month on top of the nodes — unlike EKS where it is implicit.
    Leave off below production.
  EOT
  type        = bool
  default     = false
}

variable "auto_upgrade" {
  description = "Apply patch upgrades automatically during the maintenance window"
  type        = bool
  default     = true
}

variable "maintenance_day" {
  type    = string
  default = "sunday"
}

variable "maintenance_start_time" {
  description = "Maintenance window start, 24-hour UTC, on the hour"
  type        = string
  default     = "04:00"
}

variable "destroy_associated_resources" {
  description = <<-EOT
    Delete load balancers and volumes the cluster created when the cluster is
    destroyed. Without it a destroy silently leaves the ingress load balancer
    and every PVC behind, still billing. Safe for disposable tiers; consider
    false where volumes hold data you would want to recover.
  EOT
  type        = bool
  default     = true
}

variable "registry_integration" {
  description = "Attach the DigitalOcean Container Registry. Not needed when pulling from GHCR."
  type        = bool
  default     = false
}

variable "tags" {
  description = "DigitalOcean resource tags (a list, not a map)"
  type        = list(string)
  default     = []
}
