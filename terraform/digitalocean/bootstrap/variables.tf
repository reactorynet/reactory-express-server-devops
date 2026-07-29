variable "state_bucket_name" {
  description = "Globally unique Spaces bucket name for Terraform state"
  type        = string
}

variable "spaces_region" {
  description = "Spaces region, e.g. nyc3, ams3, sgp1, fra1. Not every DO region has Spaces."
  type        = string
  default     = "nyc3"
}

variable "state_version_retention_days" {
  description = "Days to keep noncurrent state versions"
  type        = number
  default     = 90
}
