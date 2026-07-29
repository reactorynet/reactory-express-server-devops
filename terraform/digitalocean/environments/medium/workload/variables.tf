# ---------------------------------------------------------------------------
# Cluster layer state location (Spaces)
# ---------------------------------------------------------------------------
variable "state_bucket" {
  description = "Spaces bucket holding the cluster layer's state (from digitalocean/bootstrap)"
  type        = string
}

variable "state_endpoint" {
  description = "Spaces S3 endpoint, e.g. https://nyc3.digitaloceanspaces.com"
  type        = string
}

# ---------------------------------------------------------------------------
# Images
#
# DigitalOcean has a container registry, but these blueprints pull from GHCR so
# one registry serves DigitalOcean, Linode and anything else. Set registry_auth
# below for a private repository.
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
  type    = string
  default = "reactorynet/reactory-pwa-client"
}

variable "image_tag" {
  description = "Image tag to deploy"
  type        = string
  default     = "latest"
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
# Ingress and TLS
# ---------------------------------------------------------------------------
variable "domain_name" {
  description = "Domain for the Ingress host rule. Empty serves plain HTTP on the load balancer IP."
  type        = string
  default     = ""
}

variable "enable_tls" {
  description = <<-EOT
    Install cert-manager and request a Let's Encrypt certificate. Requires
    domain_name to already resolve to the load balancer IP — the HTTP-01
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
    Public base URL the server advertises. Defaults to https://<domain_name>.
    With no domain the load balancer IP is unknown until after apply — read
    load_balancer_ip from the outputs, set this, and re-apply.
  EOT
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Databases still in-cluster at this tier (MongoDB, Meilisearch).
# PostgreSQL and Valkey are managed — their names and generated credentials
# arrive from the cluster layer.
# ---------------------------------------------------------------------------
variable "mongo_database" {
  type    = string
  default = "reactory"
}

variable "mongodb_storage_size" {
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

variable "meilisearch_master_key" {
  type      = string
  sensitive = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password — this tier installs the monitoring stack"
  type        = string
  sensitive   = true
}

variable "app_secret_key" {
  description = "Application signing key — becomes SECRET_SAUCE"
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Scaling — more than one replica so PDBs and rolling updates behave as they
# will at the large tier.
# ---------------------------------------------------------------------------
variable "express_server_replicas" {
  type    = number
  default = 2
}

variable "express_server_max_replicas" {
  type    = number
  default = 4
}

variable "pwa_client_replicas" {
  type    = number
  default = 2
}

variable "pwa_client_max_replicas" {
  type    = number
  default = 3
}
