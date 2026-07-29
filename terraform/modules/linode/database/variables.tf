variable "label" {
  description = "Database cluster label"
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL major version, e.g. \"16\""
  type        = string
  default     = "16"
}

variable "region" {
  description = "Must match the cluster's region"
  type        = string
}

variable "type" {
  description = <<-EOT
    Linode instance type for the database nodes, e.g. g6-nanode-1 (smallest),
    g6-standard-1, g6-standard-2. Managed Databases accept the Nanode, unlike LKE.
  EOT
  type        = string
}

variable "cluster_size" {
  description = <<-EOT
    1 for a single node with no failover, or 3 for Linode's HA configuration.
    There is no 2-node option, so HA roughly triples the cost.
  EOT
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 3], var.cluster_size)
    error_message = "Linode Managed Databases support a cluster_size of 1 or 3 only."
  }
}

variable "vpc_id" {
  type = number
}

variable "subnet_id" {
  type = number
}

variable "public_access" {
  description = <<-EOT
    Expose a public endpoint. Leave false — with the database on the cluster's
    VPC there is no reason to, and enabling it makes allow_list the only thing
    between the database and the internet.
  EOT
  type        = bool
  default     = false
}

variable "allow_list" {
  description = "IPs permitted to connect. Only consulted when public_access is true."
  type        = list(string)
  default     = []
}

variable "maintenance_day" {
  description = "Numeric day of week: 1 is Monday through 7 which is Sunday"
  type        = number
  default     = 7
}

variable "maintenance_hour" {
  type    = number
  default = 4
}
