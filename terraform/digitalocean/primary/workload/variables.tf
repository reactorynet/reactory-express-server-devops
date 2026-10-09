# ---------------------------------------------------------------------------
# module: digitalocean/primary/workload — inputs
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Cluster access (existing, externally-managed DOKS cluster)
# ---------------------------------------------------------------------------
variable "kubeconfig_path" {
  description = <<-EOT
    Path to the kubeconfig used to reach the existing cluster. The kubernetes
    and helm providers read this directly, so `doctl` is not required.
  EOT
  type        = string
  default     = "~/.kube/reactory-primary.yaml"
}

variable "kubeconfig_context" {
  description = "Context within the kubeconfig. Empty uses the file's current-context."
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "Cluster name — used in labels and the DO load balancer name only."
  type        = string
  default     = "do-fra1-k8s-reactory-pimary"
}

variable "namespace" {
  description = "Namespace the Reactory workloads are created in"
  type        = string
  default     = "reactory"
}

variable "storage_class" {
  description = "StorageClass for all PVCs. DOKS provides do-block-storage (delete) and do-block-storage-retain (retain)."
  type        = string
  default     = "do-block-storage"
}

# ---------------------------------------------------------------------------
# Hostnames and DNS
# ---------------------------------------------------------------------------
variable "dns_zone" {
  description = "Zone the stack's A records are created in (must already exist in the DO account)"
  type        = string
  default     = "reactory.net"
}

variable "host_prefix" {
  description = <<-EOT
    Optional sub-domain label every host is placed under. Empty takes the apex
    names (@, api, apex, compute). Set it (e.g. "doks") to stage a parallel set
    under a sub-domain instead — useful while validating alongside a live stack.
  EOT
  type        = string
  default     = ""
}

variable "load_balancer_ip" {
  description = <<-EOT
    External IP of the ingress load balancer. Empty skips DNS record creation.
    Read it from the load_balancer_ip output after the first apply, then set it
    (TF_VAR_load_balancer_ip) and re-apply to create the A records and let
    cert-manager complete the ACME challenges.
  EOT
  type        = string
  default     = ""
}

variable "manage_dns" {
  description = <<-EOT
    Create the A records in DigitalOcean DNS from this layer. Requires
    DIGITALOCEAN_TOKEN. Records are only created once the load balancer IP is
    known (the second apply). Set false to manage DNS elsewhere.
  EOT
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Images (private GHCR)
# ---------------------------------------------------------------------------
variable "image_registry" {
  type    = string
  default = "ghcr.io"
}

variable "image_tag" {
  description = "Tag to deploy for every PWA client image"
  type        = string
  default     = "1.1.0"
}

variable "express_server_image_tag" {
  description = "Tag for the express-server image. Empty falls back to image_tag, so a client-only release does not force a server rebuild."
  type        = string
  default     = ""
}

variable "express_server_image" {
  type    = string
  default = "reactorynet/reactory-express-server"
}

variable "pwa_client_image" {
  description = "Primary (reactory) PWA client image"
  type        = string
  default     = "reactorynet/reactory-pwa-client"
}

variable "booktutor_image" {
  type    = string
  default = "reactorynet/booktutor-pwa-client"
}

variable "compute_planner_image" {
  description = "Solar Compute Planner PWA client image. Must be built and pushed before apply."
  type        = string
  default     = "reactorynet/compute-planner-pwa-client"
}

variable "socialeyes_image" {
  description = "SocialEyes PWA client image. Only used when deploy_socialeyes is true."
  type        = string
  default     = "reactorynet/socialeyes-pwa-client"
}

variable "registry_username" {
  description = "GHCR username for the imagePullSecret (GitHub account)"
  type        = string
  sensitive   = true
}

variable "registry_token" {
  description = "GHCR token (GitHub PAT with read:packages) for the imagePullSecret"
  type        = string
  sensitive   = true
}

variable "deploy_compute_planner" {
  description = <<-EOT
    Deploy the Solar Compute Planner PWA client. Requires a published
    ghcr.io/<org>/compute-planner-pwa-client image; there is not one yet, so
    set this false for the first bring-up and enable it once the image exists.
  EOT
  type        = bool
  default     = true
}

variable "deploy_socialeyes" {
  description = <<-EOT
    Deploy a SocialEyes PWA client. Left off by default: the SocialEyes module
    ships in the express server, but there is no SocialEyes client config or
    client image in the estate yet, so enabling this requires both to exist.
  EOT
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
variable "node_env" {
  description = "NODE_ENV / MODE for the server and Meilisearch environment"
  type        = string
  default     = "production"
}

variable "api_port" {
  type    = number
  default = 4000
}

variable "express_liveness_path" {
  description = <<-EOT
    Liveness probe path.

    Must answer 2xx without authentication and without consulting dependencies.
    Verified against the running 1.3.0 image:
      /            -> 401 (auth required)  <- not a valid probe target
      /health      -> 200 (deep sweep, ~100 services; too costly to probe)
      /health/live -> 200 (in-memory, immediate)  <- correct

    This default previously read "/" as a workaround for the 1.1.0 image, whose
    HealthRouter served only /health. Probing / returned 401, so the kubelet
    treated every cycle as a failure and SIGKILLed the container every ~5 min
    (180s delay + 6 x 20s). The 1.3.0 image serves the split routes, so the
    module default is correct again.
  EOT
  type        = string
  default     = "/health/live"
}

variable "express_readiness_path" {
  description = <<-EOT
    Readiness probe path.

    Deliberately still /health rather than the module default /health/ready:
    on the running 1.3.0 image /health/ready returns 503 because the postgres
    check fails ("No SQL connection resolved for engine \"postgres\""). Redis
    is skipped (service not registered) and mongo is healthy. Switching the
    readiness probe to /health/ready now would take the pod out of service.
    Move this to /health/ready once the postgres connection resolves and
    /health/ready returns 200.
  EOT
  type        = string
  default     = "/health"
}

variable "express_server_replicas" {
  type    = number
  default = 1
}

variable "express_server_cpu_request" {
  type    = string
  default = "100m"
}

variable "express_server_memory_request" {
  type    = string
  default = "512Mi"
}

variable "express_server_cpu_limit" {
  type    = string
  default = "1"
}

variable "express_server_memory_limit" {
  type    = string
  default = "2Gi"
}

variable "pwa_client_replicas" {
  type    = number
  default = 1
}

variable "wait_for_rollout" {
  description = "Block apply until the server and client Deployments finish rolling out. Set false while images are still being published."
  type        = bool
  default     = true
}

variable "reactory_data_storage_size" {
  description = "Size of the /reactory/reactory-data PVC"
  type        = string
  default     = "10Gi"
}

# ---------------------------------------------------------------------------
# Application environment
#
# The reactory_app module derives connection and path variables; anything it
# cannot know (tenant bootstrap secrets, provider keys, enablement flags) is
# supplied here and rendered verbatim into the express-server container.
# ---------------------------------------------------------------------------
variable "app_extra_env" {
  description = "Extra environment variables for the express-server container"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Ingress + TLS
# ---------------------------------------------------------------------------
variable "enable_tls" {
  description = "Install cert-manager and request Let's Encrypt certificates for every host"
  type        = bool
  default     = true
}

variable "acme_email" {
  description = "Contact address for Let's Encrypt expiry notices"
  type        = string
  default     = ""
}

variable "acme_server" {
  description = "ACME directory URL. Defaults to Let's Encrypt production; set the staging URL while validating DNS."
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "acme_cluster_issuer_name" {
  description = "ClusterIssuer name. Must match the cluster-issuer annotation the reactory_app module writes (letsencrypt-prod)."
  type        = string
  default     = "letsencrypt-prod"
}

variable "ingress_replicas" {
  type    = number
  default = 1
}

variable "ingress_service_annotations" {
  description = "Extra annotations merged onto the ingress-nginx LoadBalancer Service"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Telemetry
# ---------------------------------------------------------------------------
variable "expose_telemetry" {
  description = "Create ingresses for Grafana, Prometheus and Jaeger behind the same load balancer"
  type        = bool
  default     = true
}

variable "telemetry_namespace" {
  type    = string
  default = "monitoring"
}

variable "prometheus_retention" {
  type    = string
  default = "15d"
}

variable "prometheus_storage_size" {
  type    = string
  default = "20Gi"
}

variable "install_jaeger" {
  type    = bool
  default = true
}

variable "grafana_service_name" {
  type    = string
  default = "kube-prometheus-stack-grafana"
}

variable "grafana_service_port" {
  type    = number
  default = 80
}

variable "prometheus_service_name" {
  type    = string
  default = "kube-prometheus-stack-prometheus"
}

variable "prometheus_service_port" {
  type    = number
  default = 9090
}

variable "jaeger_service_name" {
  description = "Adjust if the Jaeger chart renames the query service"
  type        = string
  default     = "jaeger-query"
}

variable "jaeger_service_port" {
  type    = number
  default = 16686
}

# ---------------------------------------------------------------------------
# Databases (all in-cluster)
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
# Secrets — supply via TF_VAR_* from .env.digitalocean.
# These are written into Kubernetes Secrets and therefore into this layer's state.
# ---------------------------------------------------------------------------
variable "mongo_username" {
  type      = string
  sensitive = true
  default   = "reactory"
}

variable "mongo_password" {
  type      = string
  sensitive = true
}

variable "postgres_username" {
  type      = string
  sensitive = true
  default   = "reactory"
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
  type      = string
  sensitive = true
}

variable "app_secret_key" {
  description = "Application signing key — becomes SECRET_SAUCE / SESSION_SECRET"
  type        = string
  sensitive   = true
}
