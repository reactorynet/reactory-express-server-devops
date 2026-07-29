variable "repository_prefix" {
  description = <<-EOT
    Namespace for the repository names, giving <prefix>/express-server and
    <prefix>/pwa-client.

    The registry is shared across environments by design: an image is built and
    pushed once, then the same digest is promoted dev -> staging -> production.
    Only override this to isolate an account or a fork — a per-environment prefix
    means each environment runs a separately built artifact, which defeats the
    point of promoting a tested one.
  EOT
  type        = string
  default     = "reactory"
}

variable "force_delete" {
  description = <<-EOT
    Allow deleting a repository that still contains images. Keep this false for a
    shared registry — the repositories outlive any single environment, and a dev
    teardown must not be able to remove images production is running.
  EOT
  type        = bool
  default     = false
}

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

variable "allowed_pull_account_ids" {
  description = "Optional list of AWS account IDs that may pull images (cross-account)"
  type        = list(string)
  default     = null
}
