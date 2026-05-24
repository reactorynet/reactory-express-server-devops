variable "cluster_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR — used for security group ingress rule"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DocumentDB subnet group"
  type        = list(string)
}

variable "master_username" {
  description = "Master username"
  type        = string
  default     = "reactory"
}

variable "master_password" {
  description = "Master password — store in Secrets Manager, not tfvars"
  type        = string
  sensitive   = true
}

variable "engine_version" {
  description = "DocumentDB engine version"
  type        = string
  default     = "5.0.0"
}

variable "instance_class" {
  description = "DocumentDB instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "instance_count" {
  description = "Number of DocumentDB instances (1 = primary only; >=2 = HA)"
  type        = number
  default     = 1
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (set true for dev only)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
