# ---------------------------------------------------------------------------
# Where to read the cluster layer's state from.
#
# These must match what the cluster layer was initialised with. bin/terraform.sh
# sets them from TF_STATE_BUCKET / TF_STATE_REGION in the environment file.
# ---------------------------------------------------------------------------
variable "state_bucket" {
  description = "S3 bucket holding the cluster layer's state (from aws/bootstrap)"
  type        = string
}

variable "state_bucket_region" {
  description = "Region of the state bucket"
  type        = string
  default     = "us-west-1"
}

# ---------------------------------------------------------------------------
# Images — the registry lives in aws/bootstrap and is shared by every
# environment, so the URLs are inputs here rather than locally created outputs.
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
  description = "Image tag to deploy. Promote the same tag through dev -> staging -> production."
  type        = string
  default     = "latest"
}

# ---------------------------------------------------------------------------
# Ingress
# ---------------------------------------------------------------------------
variable "domain_name" {
  description = "Optional domain for ACM and the Ingress host rule. Empty means plain HTTP on the ALB hostname."
  type        = string
  default     = ""
}

variable "api_uri_root" {
  description = <<-EOT
    Public base URL the server advertises. Defaults to https://<domain_name> when
    a domain is set. With no domain the ALB hostname is unknown until after apply
    — read alb_dns_name from the outputs, set this, and re-apply if a browser has
    to reach the API.
  EOT
  type        = string
  default     = ""
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

variable "mongodb_image_tag" {
  type    = string
  default = "7.0.14"
}

variable "postgres_image_tag" {
  type    = string
  default = "16.4"
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
  default = "5Gi"
}

# ---------------------------------------------------------------------------
# Observability
#
# Grafana's admin password is also held in Secrets Manager, but the
# kube-prometheus-stack chart takes it as a Helm value rather than reading a
# projected Secret, so it is passed in directly here.
# ---------------------------------------------------------------------------
variable "grafana_admin_password" {
  type      = string
  sensitive = true
}
