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
# No databases run in-cluster at this tier. Every name, endpoint and generated
# credential arrives from the cluster layer through remote state.
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Secrets — supply via TF_VAR_* environment variables.
# These are written into Kubernetes Secrets and therefore into this layer's state.
# ---------------------------------------------------------------------------
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
# Scaling
# ---------------------------------------------------------------------------
variable "express_server_replicas" {
  type    = number
  default = 3
}

variable "express_server_max_replicas" {
  description = "Keep the cluster layer's max_nodes comfortably above what this can demand"
  type        = number
  default     = 10
}

variable "pwa_client_replicas" {
  type    = number
  default = 2
}

variable "pwa_client_max_replicas" {
  type    = number
  default = 6
}

variable "ingress_replica_count" {
  description = "ingress-nginx replicas. More than one so a node drain does not drop all ingress."
  type        = number
  default     = 3
}
