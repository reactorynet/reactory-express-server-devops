output "secret_arns" {
  description = "Map of secret name to ARN"
  value       = { for k, v in aws_secretsmanager_secret.reactory : k => v.arn }
}

output "eso_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  value       = aws_iam_role.eso.arn
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore resource"
  value       = "aws-secrets-manager"
}
