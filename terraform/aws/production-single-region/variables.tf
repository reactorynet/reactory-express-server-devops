variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "project" {
  description = "Project name — prefix for all resource names"
  type        = string
  default     = "reactory"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-west-1a", "us-west-1c"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/23", "10.0.12.0/23"]
}

variable "public_api_endpoint" {
  description = "Whether the Kubernetes API server is publicly reachable"
  type        = bool
  default     = true
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API server"
  type        = list(string)
  default     = []   # set to your office/VPN CIDRs in production
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS node group"
  type        = list(string)
  default     = ["m6a.large", "m6i.large"]
}

variable "image_tag" {
  description = "Container image tag to deploy"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name — used for ACM certificate and Ingress host rule"
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional SANs for ACM certificate (e.g. www.example.com)"
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Scaling
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
# Managed data services
# ---------------------------------------------------------------------------
variable "docdb_instance_class" {
  description = "DocumentDB instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "rds_max_capacity" {
  description = "Aurora Serverless v2 max ACU capacity"
  type        = number
  default     = 16
}

variable "valkey_node_type" {
  description = "ElastiCache Valkey node type"
  type        = string
  default     = "cache.r7g.large"
}

variable "opensearch_instance_type" {
  description = "OpenSearch data node instance type"
  type        = string
  default     = "r6g.large.search"
}

variable "opensearch_volume_size_gb" {
  description = "EBS volume size per OpenSearch data node"
  type        = number
  default     = 100
}

variable "mongo_database" {
  type    = string
  default = "reactory"
}

variable "postgres_database" {
  type    = string
  default = "reactory"
}

# ---------------------------------------------------------------------------
# Secrets — supply via TF_VAR_* environment variables; never commit values
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
  description = "ElastiCache Valkey AUTH token — min 16 characters"
  type        = string
  sensitive   = true
}

variable "opensearch_username" {
  type      = string
  sensitive = true
  default   = "reactory_admin"
}

variable "opensearch_password" {
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
