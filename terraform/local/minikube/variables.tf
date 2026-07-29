variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}

variable "kube_context" {
  description = "kubectl context. bin/minikube-up.sh creates the profile, which creates a context of the same name."
  type        = string
  default     = "reactory"
}

variable "namespace" {
  type    = string
  default = "reactory"
}

# ---------------------------------------------------------------------------
# Images
#
# Side-loaded with `minikube image load`, not pulled. The names must match the
# local tags exactly, including any registry prefix the build tool applies —
# podman writes localhost/<name>, docker does not.
# ---------------------------------------------------------------------------
variable "express_server_image" {
  type    = string
  default = "localhost/reactory/reactory-express-server:1.1.0"
}

variable "pwa_client_image" {
  type    = string
  default = "localhost/reactory/reactory-pwa-client:1.1.0"
}

# ---------------------------------------------------------------------------
# Ingress
# ---------------------------------------------------------------------------
variable "enable_ingress" {
  description = "Create the Ingress. Needs `minikube addons enable ingress`."
  type        = bool
  default     = true
}

variable "ingress_host" {
  description = <<-EOT
    Hostname for the Ingress rule. The default resolves through nip.io to the
    minikube IP, so no /etc/hosts entry is needed — bin/minikube-up.sh prints the
    exact value to use.
  EOT
  type        = string
  default     = "reactory.192.168.105.2.nip.io"
}

variable "api_uri_root" {
  description = "Override the base URL the server advertises; defaults to http://<ingress_host>"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Data services
# ---------------------------------------------------------------------------
variable "mongo_database" {
  type    = string
  default = "reactory"
}

variable "postgres_database" {
  type    = string
  default = "reactory"
}

variable "storage_size" {
  description = "PVC size for each data service. minikube's hostPath provisioner does not enforce it."
  type        = string
  default     = "2Gi"
}

variable "wait_for_app_rollout" {
  description = <<-EOT
    Block the apply until the application pods are ready. Off by default: the
    images are side-loaded, so a first apply before `bin/bit.sh` has built them
    would otherwise hang in ImagePullBackOff for the full provider timeout.
    Turn it on once you want a failed rollout to fail the apply.
  EOT
  type        = bool
  default     = false
}

variable "enable_observability" {
  description = "Install kube-prometheus-stack. Heavy for a laptop — off unless that is what you are testing."
  type        = bool
  default     = false
}

variable "enable_jaeger" {
  type    = bool
  default = false
}

# ---------------------------------------------------------------------------
# Secrets
#
# Defaulted, unlike every cloud tier: this is a disposable local cluster with no
# inbound exposure, and having to export eight variables to try something out is
# friction with no security benefit. Override any of them if you want.
# ---------------------------------------------------------------------------
variable "mongo_username" {
  type      = string
  sensitive = true
  default   = "reactory"
}

variable "mongo_password" {
  type      = string
  sensitive = true
  default   = "reactory-local-dev"
}

variable "postgres_username" {
  type      = string
  sensitive = true
  default   = "reactory"
}

variable "postgres_password" {
  type      = string
  sensitive = true
  default   = "reactory-local-dev"
}

variable "valkey_auth_token" {
  type      = string
  sensitive = true
  default   = "reactory-local-dev-token"
}

variable "meilisearch_master_key" {
  type      = string
  sensitive = true
  default   = "reactory-local-dev-meili-master-key"
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
  default   = "reactory-local-dev"
}

variable "app_secret_key" {
  type      = string
  sensitive = true
  default   = "reactory-local-dev-secret-sauce"
}
