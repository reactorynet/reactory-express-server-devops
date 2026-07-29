variable "state_bucket_name" {
  description = "Globally unique Object Storage bucket label for Terraform state"
  type        = string
}

variable "object_storage_region" {
  description = "Object Storage region id, e.g. us-ord-1, eu-central-1, ap-south-1"
  type        = string
  default     = "us-ord-1"
}

variable "state_version_retention_days" {
  type    = number
  default = 90
}

variable "create_access_key" {
  description = "Create an access key scoped to this bucket. Disable to reuse an existing key."
  type        = bool
  default     = true
}
