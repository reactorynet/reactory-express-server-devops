variable "namespace" {
  type = string
}

variable "name" {
  description = "Object name and Service DNS label"
  type        = string
  default     = "valkey"
}

variable "secret_name" {
  description = "Kubernetes Secret holding the AUTH password"
  type        = string
}

variable "password_key" {
  type    = string
  default = "auth_token"
}

variable "image_repository" {
  type    = string
  default = "valkey/valkey"
}

variable "image_tag" {
  type    = string
  default = "8.0-alpine"
}

variable "maxmemory" {
  description = "Valkey maxmemory. Keep below the container memory limit."
  type        = string
  default     = "256mb"
}

variable "maxmemory_policy" {
  description = "Eviction policy once maxmemory is reached"
  type        = string
  default     = "allkeys-lru"
}

variable "persistence_enabled" {
  description = <<-EOT
    Attach a PVC and enable append-only persistence. Off by default — a cache
    that can be rebuilt does not need a volume, and skipping it removes the
    Recreate-strategy volume-detach delay on every rollout.
  EOT
  type        = bool
  default     = false
}

variable "storage_class" {
  description = "StorageClass for the PVC; only used when persistence_enabled"
  type        = string
  default     = null
}

variable "storage_size" {
  type    = string
  default = "1Gi"
}

variable "cpu_request" {
  type    = string
  default = "50m"
}

variable "cpu_limit" {
  type    = string
  default = "500m"
}

variable "memory_request" {
  type    = string
  default = "64Mi"
}

variable "memory_limit" {
  description = "Container memory limit. Must exceed maxmemory with headroom for overhead."
  type        = string
  default     = "384Mi"
}

variable "labels" {
  type    = map(string)
  default = {}
}
