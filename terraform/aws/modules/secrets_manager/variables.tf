variable "cluster_name" {
  description = "EKS cluster name — used for IAM resource naming"
  type        = string
}

variable "secret_prefix" {
  description = "Secrets Manager path prefix, e.g. reactory/dev"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN (from the eks module)"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC provider URL without https:// (from the eks module)"
  type        = string
}

variable "recovery_window_days" {
  description = "Days before a deleted secret is purged (0 = immediate, dev only)"
  type        = number
  default     = 7

  validation {
    condition     = var.recovery_window_days == 0 || (var.recovery_window_days >= 7 && var.recovery_window_days <= 30)
    error_message = "recovery_window_days must be 0 (immediate) or between 7 and 30 — Secrets Manager rejects anything else."
  }
}

variable "enabled_secrets" {
  description = <<-EOT
    Which secrets this environment needs. Supplying a name here means the
    matching value variables must be set. Dev has no OpenSearch; production has
    no Meilisearch.
  EOT
  type        = list(string)
  default     = ["mongo", "postgres", "valkey", "grafana", "app"]

  validation {
    condition = length(setsubtract(
      toset(var.enabled_secrets),
      toset(["mongo", "postgres", "valkey", "meili", "opensearch", "grafana", "app"])
    )) == 0
    error_message = "enabled_secrets may only contain: mongo, postgres, valkey, meili, opensearch, grafana, app."
  }
}

# ---------------------------------------------------------------------------
# ESO service account identity — must match what the external_secrets module
# installs, since the IAM trust policy is pinned to it.
# ---------------------------------------------------------------------------
variable "eso_namespace" {
  type    = string
  default = "external-secrets"
}

variable "eso_service_account" {
  type    = string
  default = "external-secrets"
}

# ---------------------------------------------------------------------------
# Secret values — sensitive; supply via TF_VAR_* environment variables.
# ---------------------------------------------------------------------------
variable "mongo_username" {
  type      = string
  sensitive = true
  default   = ""
}

variable "mongo_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "postgres_username" {
  type      = string
  sensitive = true
  default   = ""
}

variable "postgres_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "valkey_auth_token" {
  type      = string
  sensitive = true
  default   = ""
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
  default   = ""
}

variable "app_secret_key" {
  description = "Application signing key — becomes SECRET_SAUCE"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
