variable "namespace" {
  description = "Namespace the Secrets are created in (must already exist)"
  type        = string
}

variable "enabled_secrets" {
  description = <<-EOT
    Which Secrets to create. Supplying a name means its value variables must be
    set. Tiers differ: a small tier running everything in-cluster needs meili but
    not opensearch, a large tier the reverse.
  EOT
  type        = list(string)

  validation {
    condition = length(setsubtract(
      toset(var.enabled_secrets),
      toset(["mongo", "postgres", "valkey", "meili", "opensearch", "grafana", "app"])
    )) == 0
    error_message = "enabled_secrets may only contain: mongo, postgres, valkey, meili, opensearch, grafana, app."
  }
}

variable "labels" {
  type    = map(string)
  default = {}
}

# ---------------------------------------------------------------------------
# Registry credentials — for private images (e.g. a private GHCR repository)
# ---------------------------------------------------------------------------
variable "registry_auth" {
  description = <<-EOT
    Credentials for a private image registry. Leave null for public images.
    For GHCR, username is the GitHub account and password a PAT with read:packages.
  EOT
  type = object({
    server   = string
    username = string
    password = string
  })
  default   = null
  sensitive = true
}

variable "registry_secret_name" {
  type    = string
  default = "registry-credentials"
}

# ---------------------------------------------------------------------------
# Secret values — all sensitive; supply via TF_VAR_* environment variables.
# These end up in Terraform state; see the note at the top of main.tf.
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
