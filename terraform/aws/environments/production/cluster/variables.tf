variable "aws_region" {
  type    = string
  default = "us-west-1"
}

variable "project" {
  type    = string
  default = "reactory"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "kubernetes_version" {
  description = "EKS version. Rehearse every upgrade in staging before changing this."
  type        = string
  default     = "1.30"
}

# ---------------------------------------------------------------------------
# Network — a distinct CIDR from dev (10.0/16) and staging (10.1/16)
# ---------------------------------------------------------------------------
variable "vpc_cidr" {
  type    = string
  default = "10.2.0.0/16"
}

variable "availability_zones" {
  description = "us-west-1 has exactly two AZs. Override for a 3-AZ region along with the subnet CIDRs."
  type        = list(string)
  default     = ["us-west-1a", "us-west-1c"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.2.0.0/24", "10.2.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.2.10.0/23", "10.2.12.0/23"]
}

variable "public_api_endpoint" {
  description = "Whether the Kubernetes API server is reachable from the internet"
  type        = bool
  default     = true
}

variable "api_allowed_cidrs" {
  description = <<-EOT
    CIDRs allowed to reach the Kubernetes API server. Defaults to empty — set
    your office and CI egress ranges. Leaving the production API server open to
    0.0.0.0/0 is not a default worth shipping.
  EOT
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------
variable "node_instance_types" {
  type    = list(string)
  default = ["m6a.large", "m6i.large"]
}

variable "node_desired_count" {
  type    = number
  default = 2
}

variable "node_min_count" {
  type    = number
  default = 2
}

variable "node_max_count" {
  type    = number
  default = 8
}

# ---------------------------------------------------------------------------
# Managed data services
# ---------------------------------------------------------------------------
variable "docdb_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "rds_min_capacity" {
  description = "Aurora Serverless v2 minimum ACU. Too low and the first query after idle pays a scale-up."
  type        = number
  default     = 1
}

variable "rds_max_capacity" {
  type    = number
  default = 16
}

variable "valkey_node_type" {
  type    = string
  default = "cache.r7g.large"
}

variable "opensearch_instance_type" {
  type    = string
  default = "r6g.large.search"
}

variable "opensearch_volume_size_gb" {
  type    = number
  default = 100
}

variable "backup_retention_days" {
  description = "DocumentDB automated backup retention"
  type        = number
  default     = 14
}

variable "secret_recovery_window_days" {
  description = "Days a deleted secret remains recoverable. Must not be 0 in production."
  type        = number
  default     = 30

  validation {
    condition     = var.secret_recovery_window_days >= 7
    error_message = "Production must keep a recovery window of at least 7 days — 0 deletes secrets irreversibly."
  }
}

variable "postgres_database" {
  type    = string
  default = "reactory"
}

# ---------------------------------------------------------------------------
# Secrets — supply via TF_VAR_* environment variables
# ---------------------------------------------------------------------------
variable "mongo_username" {
  type      = string
  sensitive = true
}

variable "mongo_password" {
  type      = string
  sensitive = true
}

variable "postgres_username" {
  type      = string
  sensitive = true
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "valkey_auth_token" {
  description = "ElastiCache Valkey AUTH token — 16-128 chars, no '/', '\"' or '@'"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.valkey_auth_token) >= 16 && length(var.valkey_auth_token) <= 128
    error_message = "valkey_auth_token must be between 16 and 128 characters."
  }

  validation {
    condition     = !can(regex("[/\"@]", var.valkey_auth_token))
    error_message = "valkey_auth_token must not contain '/', '\"' or '@' — ElastiCache rejects these."
  }
}

variable "opensearch_username" {
  type      = string
  sensitive = true
  default   = "reactory_admin"
}

variable "opensearch_password" {
  description = "OpenSearch master password — needs upper, lower, digit and symbol"
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "app_secret_key" {
  type      = string
  sensitive = true
}
