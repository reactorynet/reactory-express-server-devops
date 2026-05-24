variable "cluster_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "mode" {
  description = "Deployment mode: managed | serverless"
  type        = string
  default     = "managed"
  validation {
    condition     = contains(["managed", "serverless"], var.mode)
    error_message = "Must be managed or serverless."
  }
}

variable "vpc_id" {
  description = "VPC ID (managed mode only)"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "VPC CIDR for security group / access policy (managed mode)"
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (managed mode — one per AZ)"
  type        = list(string)
  default     = []
}

variable "vpce_ids" {
  description = "VPC endpoint IDs for serverless network policy"
  type        = list(string)
  default     = []
}

variable "engine_version" {
  description = "OpenSearch version (managed mode), e.g. 2.13"
  type        = string
  default     = "2.13"
}

variable "instance_type" {
  description = "OpenSearch data node instance type"
  type        = string
  default     = "t3.small.search"
}

variable "instance_count" {
  description = "Number of data nodes (use 2+ for AZ awareness)"
  type        = number
  default     = 1
}

variable "volume_size_gb" {
  description = "EBS volume size per node in GB"
  type        = number
  default     = 20
}

variable "master_username" {
  description = "Master username for fine-grained access control"
  type        = string
  default     = "reactory"
}

variable "master_password" {
  description = "Master password — must satisfy complexity requirements"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
