output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.eks.cluster_endpoint
}

output "ecr_express_server_url" {
  description = "ECR URL for express-server — use in CI/CD push step"
  value       = module.ecr.express_server_url
}

output "ecr_pwa_client_url" {
  description = "ECR URL for pwa-client — use in CI/CD push step"
  value       = module.ecr.pwa_client_url
}

output "valkey_endpoint" {
  description = "ElastiCache Valkey primary endpoint"
  value       = module.valkey.primary_endpoint
}

output "meilisearch_endpoint" {
  description = "In-cluster Meilisearch endpoint"
  value       = module.meilisearch.service_endpoint
}

output "kubeconfig_command" {
  description = "Run this to update your local kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
