variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "project" {
  description = "Project name — used as a prefix for all resource names"
  type        = string
  default     = "reactory"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to use (us-west-1 has 2)"
  type        = list(string)
  default     = ["us-west-1a", "us-west-1c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.10.0/23", "10.0.12.0/23"]
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to access the Kubernetes API server"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "image_tag" {
  description = "Container image tag to deploy for both express-server and pwa-client"
  type        = string
  default     = "latest"
}

variable "domain_name" {
  description = "Optional: domain name for ACM certificate and Ingress host rule"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Secret variables — supply via TF_VAR_* env vars or a secrets backend.
# Never commit actual values to source control.
# ---------------------------------------------------------------------------
variable "mongo_username" {
  type      = string
  sensitive = true
}

variable "mongo_password" {
  type      = string
  sensitive = true
}

variable "mongo_database" {
  type    = string
  default = "reactory"
}

variable "postgres_username" {
  type      = string
  sensitive = true
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "postgres_database" {
  type    = string
  default = "reactory"
}

variable "valkey_auth_token" {
  description = "ElastiCache Valkey AUTH token — min 16 characters"
  type        = string
  sensitive   = true
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
  description = "Application secret key for JWT / session signing"
  type        = string
  sensitive   = true
}
