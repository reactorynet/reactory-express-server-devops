# ---------------------------------------------------------------------------
# Cluster layer state location (Spaces)
# ---------------------------------------------------------------------------
variable "state_bucket" {
  description = "Object Storage bucket holding the cluster layer's state (from linode/bootstrap)"
  type        = string
}

variable "state_endpoint" {
  description = "Object Storage S3 endpoint, e.g. https://us-ord-1.linodeobjects.com"
  type        = string
}

# ---------------------------------------------------------------------------
# Images
#
# Linode has no container registry at all, so images come from GHCR. Set
# registry_auth below for a private repository.
# ---------------------------------------------------------------------------
variable "image_registry" {
  type    = string
  default = "ghcr.io"
}

variable "express_server_image" {
  description = "Repository path within the registry, e.g. reactorynet/reactory-express-server"
  type        = string
  default     = "reactorynet/reactory-express-server"
}

variable "pwa_client_image" {
  description = "Repository path for default reactory management client, e.g. reactorynet/reactory-pwa-client"
  type        = string
  default     = "reactorynet/reactory-pwa-client"
}

variable "booktutor_client_image" {
  description = "Repository path for BookTutor client, e.g. reactorynet/booktutor-pwa-client"
  type        = string
  default     = "reactorynet/booktutor-pwa-client"
}

variable "image_tag" {
  description = "Image tag to deploy"
  type        = string
  default     = "1.1.0"
}

variable "registry_auth" {
  description = <<-EOT
    Pull credentials for a private registry. Leave null for public images.
    For GHCR: username is the GitHub account, password a PAT with read:packages.
  EOT
  type = object({
    server   = string
    username = string
    password = string
  })
  default   = null
  sensitive = true
}

# ---------------------------------------------------------------------------
# Ingress and Multi-Tenant Domains
# ---------------------------------------------------------------------------
variable "domain_name" {
  description = "Fallback domain name if specific hostnames are omitted"
  type        = string
  default     = "reactory.net"
}

variable "web_domain_name" {
  description = "Domain for the Reactory management client Ingress (e.g. reactory.net, app.reactory.net)"
  type        = string
  default     = "reactory.net"
}

variable "api_domain_name" {
  description = "Domain for the shared Express backend API Ingress (e.g. api.reactory.net)"
  type        = string
  default     = "api.reactory.net"
}

variable "booktutor_domain_name" {
  description = "Domain for the BookTutor client Ingress (e.g. apex.reactory.net)"
  type        = string
  default     = "apex.reactory.net"
}

variable "enable_tls" {
  description = <<-EOT
    Install cert-manager and request a Let's Encrypt certificate. Requires
    domain_name to already resolve to the NodeBalancer IP — the HTTP-01
    challenge must be reachable, and a failing challenge loop burns Let's
    Encrypt rate limits.
  EOT
  type        = bool
  default     = false
}

variable "acme_email" {
  description = "Contact address for Let's Encrypt expiry notices"
  type        = string
  default     = ""
}

variable "acme_server" {
  description = <<-EOT
    ACME directory URL. Defaults to Let's Encrypt STAGING — certificates are
    untrusted by browsers but effectively rate-limit free. Switch to production
    only once a staging certificate has been issued successfully.
  EOT
  type        = string
  default     = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

variable "api_uri_root" {
  description = <<-EOT
    Public base URL the server advertises. Defaults to https://api.reactory.net.
  EOT
  type        = string
  default     = "https://api.reactory.net"
}

# ---------------------------------------------------------------------------
# Databases (all in-cluster at this tier)
# ---------------------------------------------------------------------------
variable "mongo_database" {
  type    = string
  default = "reactory"
}

variable "postgres_database" {
  type    = string
  default = "reactory"
}

variable "mongodb_storage_size" {
  type    = string
  default = "5Gi"
}

variable "postgres_storage_size" {
  type    = string
  default = "5Gi"
}

variable "meilisearch_storage_size" {
  type    = string
  default = "2Gi"
}

# ---------------------------------------------------------------------------
# Secrets — supply via TF_VAR_* environment variables.
# These are written into Kubernetes Secrets and therefore into this layer's state.
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
}

variable "grafana_admin_password" {
  description = "Kept for parity with the larger tiers, which install Grafana"
  type        = string
  sensitive   = true
  default     = ""
}

variable "app_secret_key" {
  description = "Application signing key — becomes SECRET_SAUCE"
  type        = string
  sensitive   = true
}
