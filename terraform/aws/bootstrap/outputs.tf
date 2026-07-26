output "state_bucket_name" {
  description = "S3 bucket holding every environment's Terraform state"
  value       = aws_s3_bucket.tf_state.id
}

output "state_bucket_region" {
  description = "Region of the state bucket — needed in each layer's backend config"
  value       = var.aws_region
}

output "lock_table_name" {
  description = "DynamoDB table used for state locking"
  value       = aws_dynamodb_table.tf_lock.name
}

output "backend_config" {
  description = <<-EOT
    Ready-made -backend-config arguments. bin/terraform.sh passes these
    automatically; this output is for manual invocations.
  EOT
  value = join(" ", [
    "-backend-config=bucket=${aws_s3_bucket.tf_state.id}",
    "-backend-config=region=${var.aws_region}",
    "-backend-config=dynamodb_table=${aws_dynamodb_table.tf_lock.name}",
    "-backend-config=encrypt=true",
  ])
}

# ---------------------------------------------------------------------------
# Shared registry
# ---------------------------------------------------------------------------
output "ecr_express_server_url" {
  description = "Shared ECR repository for the express-server image"
  value       = module.ecr.express_server_url
}

output "ecr_pwa_client_url" {
  description = "Shared ECR repository for the pwa-client image"
  value       = module.ecr.pwa_client_url
}

output "ecr_registry" {
  description = "Registry host to docker login against"
  value       = split("/", module.ecr.express_server_url)[0]
}

output "ecr_repository_urls" {
  description = "All shared repository URLs by short name"
  value       = module.ecr.repository_urls
}
