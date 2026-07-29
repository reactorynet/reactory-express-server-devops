# ---------------------------------------------------------------------------
# Cluster layer state location
# ---------------------------------------------------------------------------
variable "state_bucket" {
  description = "S3 bucket holding the cluster layer's state (from aws/bootstrap)"
  type        = string
}

variable "state_bucket_region" {
  type    = string
  default = "us-west-1"
}

# ---------------------------------------------------------------------------
# Images — from the shared registry in aws/bootstrap
# ---------------------------------------------------------------------------
variable "ecr_express_server_url" {
  description = "Shared ECR repository URL for express-server (bootstrap output)"
  type        = string
}

variable "ecr_pwa_client_url" {
  description = "Shared ECR repository URL for pwa-client (bootstrap output)"
  type        = string
}

variable "image_tag" {
  description = <<-EOT
    Image tag to deploy. This should be a tag that has already been applied and
    verified in staging — the registry is shared, so promoting means moving this
    value forward, not rebuilding.
  EOT
  type        = string
}

# ---------------------------------------------------------------------------
# Ingress
# ---------------------------------------------------------------------------
variable "domain_name" {
  description = "Domain for ACM and the Ingress host rule. Empty means plain HTTP on the ALB hostname."
  type        = string
  default     = ""
}

variable "subject_alternative_names" {
  type    = list(string)
  default = []
}

variable "api_uri_root" {
  description = "Fallback public base URL, used only when domain_name is empty"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Scaling
#
# max_unavailable is 0 for rolling updates, so a rollout needs room to surge
# into. Keep node_max_count in the cluster layer comfortably above what these
# maxima demand, or the HPA will scale to Pending pods.
# ---------------------------------------------------------------------------
variable "express_server_replicas" {
  type    = number
  default = 2
}

variable "express_server_max_replicas" {
  type    = number
  default = 8
}

variable "pwa_client_replicas" {
  type    = number
  default = 2
}

variable "pwa_client_max_replicas" {
  type    = number
  default = 6
}

# ---------------------------------------------------------------------------
# Databases
# ---------------------------------------------------------------------------
variable "mongo_database" {
  type    = string
  default = "reactory"
}

variable "postgres_database" {
  type    = string
  default = "reactory"
}

# ---------------------------------------------------------------------------
# Observability
# ---------------------------------------------------------------------------
variable "grafana_admin_password" {
  type      = string
  sensitive = true
}
