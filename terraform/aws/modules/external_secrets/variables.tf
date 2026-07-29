variable "aws_region" {
  description = "Region the ClusterSecretStore reads Secrets Manager from"
  type        = string
}

variable "enabled_secrets" {
  description = "Services to project. Must match the cluster layer's secrets_manager output."
  type        = list(string)

  validation {
    condition = length(setsubtract(
      toset(var.enabled_secrets),
      toset(["mongo", "postgres", "valkey", "meili", "opensearch", "grafana", "app"])
    )) == 0
    error_message = "enabled_secrets may only contain: mongo, postgres, valkey, meili, opensearch, grafana, app."
  }
}

variable "secret_names" {
  description = <<-EOT
    Map of service name to Secrets Manager secret name, from the cluster layer's
    secrets_manager.secret_names output. Every entry in enabled_secrets must
    have a key here.
  EOT
  type        = map(string)
}

variable "eso_role_arn" {
  description = "IRSA role ARN from the cluster layer, annotated onto the ESO service account"
  type        = string
}

variable "target_namespace" {
  description = "Namespace the projected Kubernetes Secrets are created in (must already exist)"
  type        = string
  default     = "reactory"
}

variable "namespace_overrides" {
  description = <<-EOT
    Per-secret namespace overrides keyed by service name, e.g.
    { grafana = "monitoring" }. The namespace must already exist — ESO does not
    create it. Anything unlisted lands in target_namespace.
  EOT
  type        = map(string)
  default     = {}
}

variable "refresh_interval" {
  description = "How often ESO re-reads each secret from Secrets Manager"
  type        = string
  default     = "1h"
}

variable "eso_namespace" {
  description = "Namespace the operator runs in. Must match the cluster layer's IAM trust policy."
  type        = string
  default     = "external-secrets"
}

variable "eso_service_account" {
  description = "Operator service account name. Must match the cluster layer's IAM trust policy."
  type        = string
  default     = "external-secrets"
}

variable "eso_chart_version" {
  description = "External Secrets Operator Helm chart version"
  type        = string
  default     = "0.9.19"
}

variable "eso_api_version" {
  description = <<-EOT
    API version for ClusterSecretStore and ExternalSecret manifests. Chart 0.9.x
    serves external-secrets.io/v1beta1; ESO >= 0.14 promoted the API to
    external-secrets.io/v1. Change this in step with eso_chart_version.
  EOT
  type        = string
  default     = "external-secrets.io/v1beta1"
}

variable "cluster_secret_store_name" {
  type    = string
  default = "aws-secrets-manager"
}

variable "helm_timeout_seconds" {
  type    = number
  default = 600
}
