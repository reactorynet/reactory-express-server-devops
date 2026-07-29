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
  default = "staging"
}

variable "kubernetes_version" {
  description = "EKS version. Keep this equal to production so upgrades rehearse here first."
  type        = string
  default     = "1.30"
}

# ---------------------------------------------------------------------------
# Network
#
# A distinct CIDR from dev and production, so the environments can be peered or
# share a transit gateway without renumbering.
# ---------------------------------------------------------------------------
variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-west-1a", "us-west-1c"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.0.0/24", "10.1.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.10.0/23", "10.1.12.0/23"]
}

variable "public_api_endpoint" {
  type    = bool
  default = true
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API server"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------
variable "node_instance_types" {
  type    = list(string)
  default = ["t3.large"]
}

variable "node_desired_count" {
  type    = number
  default = 2
}

variable "node_max_count" {
  type    = number
  default = 4
}

# ---------------------------------------------------------------------------
# Managed data services — smallest sizes that still exercise each service
# ---------------------------------------------------------------------------
variable "docdb_instance_class" {
  description = "DocumentDB instance class. db.t3.medium is the smallest available."
  type        = string
  default     = "db.t3.medium"
}

variable "rds_max_capacity" {
  description = "Aurora Serverless v2 maximum ACU"
  type        = number
  default     = 4
}

variable "valkey_node_type" {
  type    = string
  default = "cache.t4g.small"
}

variable "opensearch_instance_type" {
  type    = string
  default = "t3.small.search"
}

variable "opensearch_volume_size_gb" {
  type    = number
  default = 20
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
