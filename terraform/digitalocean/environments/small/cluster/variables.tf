variable "project" {
  type    = string
  default = "reactory"
}

variable "tier" {
  description = "Tier name — used in resource names and tags"
  type        = string
  default     = "small"
}

variable "region" {
  description = "DigitalOcean region slug, e.g. nyc3, lon1, fra1, sgp1"
  type        = string
  default     = "nyc3"
}

variable "kubernetes_version" {
  description = <<-EOT
    Exact DOKS version slug. These are retired frequently, unlike EKS minor
    versions — run `doctl kubernetes options versions` and pin a current one.
  EOT
  type        = string
  default     = "1.31.1-do.0"
}

variable "vpc_ip_range" {
  description = "CIDR for this tier's VPC. Distinct per tier so they can be peered."
  type        = string
  default     = "10.10.0.0/16"
}

variable "node_size" {
  description = <<-EOT
    Worker Droplet slug. s-2vcpu-4gb is the practical floor for this tier:
    MongoDB, PostgreSQL, Valkey, Meilisearch, ingress-nginx and both application
    pods all share the node, and DOKS reserves roughly 20% for system components.
    s-2vcpu-2gb will schedule some pods and leave others Pending.
  EOT
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "node_count" {
  type    = number
  default = 1
}
