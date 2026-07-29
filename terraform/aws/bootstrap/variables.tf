variable "aws_region" {
  description = "AWS region for the state backend and the shared registry"
  type        = string
  default     = "us-west-1"
}

variable "project" {
  description = "Project name — used in tags"
  type        = string
  default     = "reactory"
}

# ---------------------------------------------------------------------------
# State backend
# ---------------------------------------------------------------------------
variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "reactory-terraform-lock"
}

variable "state_version_retention_days" {
  description = "Days to keep noncurrent state versions before expiry"
  type        = number
  default     = 90
}

# ---------------------------------------------------------------------------
# Shared ECR registry
# ---------------------------------------------------------------------------
variable "ecr_repository_prefix" {
  description = "Repository namespace, giving <prefix>/express-server and <prefix>/pwa-client"
  type        = string
  default     = "reactory"
}

variable "ecr_max_image_count" {
  description = <<-EOT
    Tagged images retained per repository. This registry serves every
    environment, so keep enough history to roll production back past whatever dev
    has pushed since.
  EOT
  type        = number
  default     = 50
}

variable "ecr_allowed_pull_account_ids" {
  description = "Other AWS account IDs permitted to pull (cross-account deployments)"
  type        = list(string)
  default     = null
}
