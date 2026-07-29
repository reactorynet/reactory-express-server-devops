output "secret_arns" {
  description = "Map of service name to Secrets Manager ARN"
  value       = { for k, v in aws_secretsmanager_secret.reactory : k => v.arn }
}

output "secret_names" {
  description = <<-EOT
    Map of service name to Secrets Manager secret name. The workload layer feeds
    this to the external_secrets module as the remote reference for each
    ExternalSecret.
  EOT
  value       = { for k, v in aws_secretsmanager_secret.reactory : k => v.name }
}

output "enabled_secrets" {
  description = "Services this environment created secrets for"
  value       = var.enabled_secrets
}

output "eso_role_arn" {
  description = "IAM role ARN the External Secrets Operator service account annotates with"
  value       = aws_iam_role.eso.arn
}

output "eso_namespace" {
  description = "Namespace the IAM trust policy expects the operator to run in"
  value       = var.eso_namespace
}

output "eso_service_account" {
  description = "Service account name the IAM trust policy is pinned to"
  value       = var.eso_service_account
}
