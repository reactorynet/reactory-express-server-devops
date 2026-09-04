# ---------------------------------------------------------------------------
# module: reactory_app — inputs
# ---------------------------------------------------------------------------

variable "namespace" {
  description = "Namespace the workloads are created in (must already exist)"
  type        = string
}

variable "environment" {
  description = "Environment name — used in labels only"
  type        = string
}

variable "labels" {
  description = "Extra labels applied to every object"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Images
# ---------------------------------------------------------------------------
variable "express_server_image" {
  description = "Fully qualified express-server image reference including tag"
  type        = string
}

variable "pwa_client_image" {
  description = "Fully qualified pwa-client image reference including tag"
  type        = string
}

variable "image_pull_policy" {
  type    = string
  default = "IfNotPresent"

  validation {
    condition     = contains(["Always", "IfNotPresent", "Never"], var.image_pull_policy)
    error_message = "image_pull_policy must be Always, IfNotPresent or Never."
  }
}

variable "image_pull_secrets" {
  description = <<-EOT
    Names of docker-registry Secrets used to pull the images. Needed for a
    private registry — a private GHCR repository on DigitalOcean or Linode.
    Not needed for ECR, where the node role grants pull access, or for public
    images.
  EOT
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Additional Multi-Tenant Clients
# ---------------------------------------------------------------------------
variable "additional_clients" {
  description = "Map of additional PWA client applications to deploy alongside reactory-pwa-client (e.g. booktutor)"
  type = map(object({
    image           = string
    domain_name     = string
    replicas        = optional(number, 1)
    cpu_request     = optional(string, "50m")
    cpu_limit       = optional(string, "500m")
    memory_request  = optional(string, "64Mi")
    memory_limit    = optional(string, "512Mi")
    annotations     = optional(map(string), {})
    tls_secret_name = optional(string)
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# Sizing
# ---------------------------------------------------------------------------
variable "express_server" {
  description = "Replica counts and resource envelope for the API server"
  type = object({
    replicas       = optional(number, 1)
    max_replicas   = optional(number, 4)
    cpu_request    = optional(string, "250m")
    cpu_limit      = optional(string, "2")
    memory_request = optional(string, "512Mi")
    memory_limit   = optional(string, "2Gi")
  })
  default = {}
}

variable "pwa_client" {
  description = "Replica counts and resource envelope for the PWA client"
  type = object({
    replicas       = optional(number, 1)
    max_replicas   = optional(number, 4)
    cpu_request    = optional(string, "100m")
    cpu_limit      = optional(string, "500m")
    memory_request = optional(string, "128Mi")
    memory_limit   = optional(string, "512Mi")
  })
  default = {}
}

variable "enable_hpa" {
  description = "Create HorizontalPodAutoscalers. Requires metrics-server."
  type        = bool
  default     = false
}

variable "enable_pdb" {
  description = "Create PodDisruptionBudgets. Only meaningful with 2+ replicas."
  type        = bool
  default     = false
}

variable "enable_topology_spread" {
  description = <<-EOT
    Spread replicas across availability zones with DoNotSchedule. Leave false in
    single-AZ environments — there is only one zone to spread over, and the
    constraint would block scheduling beyond the first replica.
  EOT
  type        = bool
  default     = false
}

variable "wait_for_rollout" {
  description = <<-EOT
    Block the apply until the Deployment finishes rolling out.

    True is right for a cloud environment: a failed rollout should fail the
    apply rather than report success over a broken deployment.

    False suits local experimentation, where the images are side-loaded and an
    apply run before they exist would otherwise sit in ImagePullBackOff until
    the provider's 10-minute timeout expires.
  EOT
  type        = bool
  default     = true
}

variable "rolling_update" {
  description = "Rolling update envelope. max_unavailable 0 requires spare capacity to surge into."
  type = object({
    max_surge       = optional(string, "25%")
    max_unavailable = optional(string, "25%")
  })
  default = {}
}

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
variable "node_env" {
  description = "NODE_ENV / MODE value"
  type        = string
  default     = "production"
}

variable "api_port" {
  type    = number
  default = 4000
}

variable "api_uri_root" {
  description = "Public base URL the server advertises (API_URI_ROOT); CDN_ROOT derives from it"
  type        = string
  default     = "http://localhost:4000"
}

variable "reactory_paths" {
  description = "Filesystem layout inside the server image"
  type = object({
    home    = optional(string, "/reactory")
    data    = optional(string, "/reactory/reactory-data")
    server  = optional(string, "/reactory/reactory-express-server")
    client  = optional(string, "/reactory/reactory-pwa-client")
    plugins = optional(string, "/reactory/reactory-data/plugins")
  })
  default = {}
}

variable "server_command" {
  description = "Entrypoint override for the express-server container"
  type        = list(string)
  default     = ["/bin/sh"]
}

variable "server_args" {
  type    = list(string)
  default = ["-c", "sh bin/run-otel.sh"]
}

variable "extra_env" {
  description = "Additional plain environment variables for the express-server"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Data services
# ---------------------------------------------------------------------------
variable "mongo" {
  description = <<-EOT
    MongoDB / DocumentDB connection. The module composes MONGOOSE from these
    parts; it never takes a pre-built URI, so the credential interpolation
    ordering stays correct.

    ca_file must be an absolute path — the driver resolves tlsCAFile against the
    process working directory. Setting it enables the CA bundle init container.
  EOT
  type = object({
    host         = string
    port         = optional(number, 27017)
    database     = string
    secret_name  = string
    username_key = optional(string, "username")
    password_key = optional(string, "password")
    tls          = optional(bool, false)
    replica_set  = optional(string)
    ca_file      = optional(string)
    auth_source  = optional(string, "admin")
    extra_params = optional(string, "")
  })
}

variable "postgres" {
  type = object({
    host         = string
    port         = optional(number, 5432)
    database     = string
    secret_name  = string
    username_key = optional(string, "username")
    password_key = optional(string, "password")
  })
}

variable "redis" {
  description = "Valkey / Redis. tls must be true whenever an AUTH token is set on ElastiCache."
  type = object({
    host         = string
    port         = optional(number, 6379)
    db           = optional(number, 0)
    secret_name  = string
    password_key = optional(string, "auth_token")
    tls          = optional(bool, true)
  })
}

variable "search" {
  description = <<-EOT
    Search backend. provider selects which env contract the server reads:
      meilisearch   -> MEILISEARCH_HOST + MEILISEARCH_MASTER_KEY
      elasticsearch -> ELASTICSEARCH_NODE + ELASTICSEARCH_USERNAME/PASSWORD
    endpoint must include the scheme.
  EOT
  type = object({
    provider       = string
    endpoint       = string
    secret_name    = string
    master_key_key = optional(string, "master-key")
    username_key   = optional(string, "username")
    password_key   = optional(string, "password")
  })

  validation {
    condition     = contains(["meilisearch", "elasticsearch"], var.search.provider)
    error_message = "search.provider must be meilisearch or elasticsearch."
  }
}

variable "app_secret" {
  description = "Secret holding the application signing key (SECRET_SAUCE / SESSION_SECRET)"
  type = object({
    secret_name = string
    key         = optional(string, "secret_key")
  })
}

# ---------------------------------------------------------------------------
# DocumentDB TLS trust store
# ---------------------------------------------------------------------------
variable "ca_bundle_init_image" {
  description = "Init container image used to fetch the RDS CA bundle (needs curl)"
  type        = string
  default     = "curlimages/curl:8.10.1"
}

variable "ca_bundle_url" {
  description = "URL of the Amazon RDS/DocumentDB global CA bundle"
  type        = string
  default     = "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem"
}

# ---------------------------------------------------------------------------
# Ingress (Supports Dual-Domain Ingress: web_domain_name & api_domain_name)
# ---------------------------------------------------------------------------
variable "ingress" {
  description = <<-EOT
    Dual-domain ingress configuration for Reactory Web and API endpoints:
    - web_domain_name: dedicated hostname for static SPA PWA client (e.g. booktutor-web.reactory.net)
    - api_domain_name: dedicated hostname for express/apollo API server (e.g. booktutor-api.reactory.net)
    - domain_name: optional fallback for single-domain legacy setups
  EOT
  type = object({
    enabled         = optional(bool, true)
    class_name      = optional(string, "nginx")
    web_domain_name = optional(string, "")
    api_domain_name = optional(string, "")
    domain_name     = optional(string, "")
    tls_secret_name = optional(string, "reactory-tls")
    web_annotations = optional(map(string), {})
    api_annotations = optional(map(string), {})
    annotations     = optional(map(string), {})
    api_path_prefix = optional(string, "/api")
  })
  default = {}
}
