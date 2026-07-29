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
    Image tag to deploy. Promote the tag that passed dev; production should then
    receive the tag that passed here, so the same artifact moves forward.
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
# Scaling — smaller than production, but more than one replica so rolling
# updates, PDBs and topology spread all behave the way they will in production.
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
