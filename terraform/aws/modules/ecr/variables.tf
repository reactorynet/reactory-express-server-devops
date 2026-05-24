variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "max_image_count" {
  description = "Maximum number of tagged images to retain per repository"
  type        = number
  default     = 20
}

variable "force_delete" {
  description = "Allow deleting the repository even if it contains images (set true for dev)"
  type        = bool
  default     = false
}

variable "allowed_pull_account_ids" {
  description = "Optional list of AWS account IDs that may pull images (cross-account)"
  type        = list(string)
  default     = null
}
