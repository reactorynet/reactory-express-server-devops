variable "cluster_name" {
  description = "EKS cluster name — used for IAM resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "secret_prefix" {
  description = "Secrets Manager path prefix, e.g. reactory/dev"
  type        = string
  default     = "reactory"
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN (from eks module output)"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC provider URL without https:// (from eks module output)"
  type        = string
}

variable "recovery_window_days" {
  description = "Days before a deleted secret is purged (0 = immediate for dev)"
  type        = number
  default     = 7
}

variable "eso_chart_version" {
  description = "External Secrets Operator Helm chart version"
  type        = string
  default     = "0.9.19"
}

# ---------------------------------------------------------------------------
# Secret values — all sensitive; supply via environment variables or a
# secrets backend, never hardcode in tfvars.
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
  type      = string
  sensitive = true
}

variable "meilisearch_master_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "opensearch_username" {
  type      = string
  sensitive = true
  default   = ""
}

variable "opensearch_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "app_secret_key" {
  description = "Application-level secret key (JWT signing, session encryption)"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
