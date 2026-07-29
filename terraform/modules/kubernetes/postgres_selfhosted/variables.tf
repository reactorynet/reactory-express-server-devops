variable "namespace" {
  type = string
}

variable "name" {
  description = "Object name and Service DNS label"
  type        = string
  default     = "postgres"
}

variable "secret_name" {
  description = "Kubernetes Secret holding the credentials (projected by ESO)"
  type        = string
}

variable "username_key" {
  type    = string
  default = "username"
}

variable "password_key" {
  type    = string
  default = "password"
}

variable "database" {
  description = "Database created on first start"
  type        = string
}

variable "image_tag" {
  type    = string
  default = "16.4"
}

variable "storage_class" {
  type = string
}

variable "storage_size" {
  type    = string
  default = "5Gi"
}

variable "cpu_request" {
  type    = string
  default = "250m"
}

variable "cpu_limit" {
  type    = string
  default = "1"
}

variable "memory_request" {
  type    = string
  default = "256Mi"
}

variable "memory_limit" {
  type    = string
  default = "1Gi"
}

variable "labels" {
  type    = map(string)
  default = {}
}
