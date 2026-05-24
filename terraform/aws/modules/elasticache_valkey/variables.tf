variable "cluster_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR for security group ingress"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "mode" {
  description = "Deployment mode: single | cluster | serverless"
  type        = string
  default     = "single"
  validation {
    condition     = contains(["single", "cluster", "serverless"], var.mode)
    error_message = "Must be single, cluster, or serverless."
  }
}

variable "engine_version" {
  description = "Valkey engine version"
  type        = string
  default     = "8.0"
}

variable "node_type" {
  description = "ElastiCache node type (ignored for serverless)"
  type        = string
  default     = "cache.t4g.small"
}

variable "auth_token" {
  description = "AUTH token (password) for Valkey. Min 16 chars."
  type        = string
  sensitive   = true
}

variable "multi_az" {
  description = "Enable Multi-AZ automatic failover for single mode"
  type        = bool
  default     = false
}

variable "num_shards" {
  description = "Number of shards (cluster mode only)"
  type        = number
  default     = 3
}

variable "replicas_per_shard" {
  description = "Number of replica nodes per shard (cluster mode)"
  type        = number
  default     = 1
}

variable "snapshot_retention_days" {
  description = "Days to retain automatic snapshots (0 disables)"
  type        = number
  default     = 1
}

# Serverless-only variables
variable "serverless_max_storage_gb" {
  description = "Maximum data storage in GB (serverless mode)"
  type        = number
  default     = 10
}

variable "serverless_max_ecpu" {
  description = "Maximum ECPU per second (serverless mode)"
  type        = number
  default     = 5000
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
