output "repository_urls" {
  description = "Map of service name to ECR repository URL"
  value       = { for k, v in aws_ecr_repository.reactory : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of service name to ECR repository ARN"
  value       = { for k, v in aws_ecr_repository.reactory : k => v.arn }
}

output "express_server_url" {
  description = "ECR URL for the express-server image"
  value       = aws_ecr_repository.reactory["express-server"].repository_url
}

output "pwa_client_url" {
  description = "ECR URL for the pwa-client image"
  value       = aws_ecr_repository.reactory["pwa-client"].repository_url
}
