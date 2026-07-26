variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "project" {
  description = "Project name — prefix for all resource names"
  type        = string
  default     = "reactory"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.30"
}

# ---------------------------------------------------------------------------
# Network
#
# us-west-1 has only two AZs (us-west-1a, us-west-1c) and the defaults are sized
# for it. Dev uses the first entry of each list only.
# ---------------------------------------------------------------------------
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-west-1a", "us-west-1c"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/23", "10.0.12.0/23"]
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
  description = "Instance types for the SPOT node group. More types means fewer interruptions."
  type        = list(string)
  default     = ["t3.medium", "t3.large"]
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
# Managed cache
# ---------------------------------------------------------------------------
variable "valkey_node_type" {
  type    = string
  default = "cache.t4g.small"
}

# ---------------------------------------------------------------------------
# Secrets — supply via TF_VAR_* environment variables, never in tfvars.
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

variable "meilisearch_master_key" {
  type      = string
  sensitive = true
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "app_secret_key" {
  description = "Application signing key — becomes SECRET_SAUCE"
  type        = string
  sensitive   = true
}
