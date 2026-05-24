variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "image_tag" {
  description = "Meilisearch image tag — pin to a specific version"
  type        = string
  default     = "v1.9"
}

variable "master_key_secret_name" {
  description = "Kubernetes Secret name containing key 'master-key'"
  type        = string
}

variable "meili_env" {
  description = "Meilisearch environment: development | production"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["development", "production"], var.meili_env)
    error_message = "Must be development or production."
  }
}

variable "storage_class" {
  description = "Kubernetes StorageClass name for the PVC"
  type        = string
  default     = "gp3"
}

variable "storage_size" {
  description = "PVC storage size"
  type        = string
  default     = "10Gi"
}

variable "cpu_limit" {
  description = "CPU limit for the Meilisearch container"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit for the Meilisearch container"
  type        = string
  default     = "1Gi"
}
