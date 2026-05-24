output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.eks.cluster_endpoint
}

output "kubeconfig_command" {
  description = "Update local kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_express_server_url" {
  description = "ECR URL for express-server"
  value       = module.ecr.express_server_url
}

output "ecr_pwa_client_url" {
  description = "ECR URL for pwa-client"
  value       = module.ecr.pwa_client_url
}

output "documentdb_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = module.documentdb.cluster_endpoint
}

output "rds_cluster_endpoint" {
  description = "Aurora PostgreSQL writer endpoint"
  value       = module.rds.cluster_endpoint
}

output "rds_reader_endpoint" {
  description = "Aurora PostgreSQL reader endpoint"
  value       = module.rds.cluster_reader_endpoint
}

output "valkey_endpoint" {
  description = "ElastiCache Valkey primary endpoint"
  value       = module.valkey.primary_endpoint
}

output "opensearch_endpoint" {
  description = "OpenSearch Service domain endpoint"
  value       = module.opensearch.endpoint
}

output "opensearch_dashboard_endpoint" {
  description = "OpenSearch Dashboards URL"
  value       = module.opensearch.dashboard_endpoint
}

output "alb_dns_name" {
  description = "ALB DNS name — use in Route 53 ALIAS record"
  value       = module.alb_ingress.alb_dns_name
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = module.alb_ingress.acm_certificate_arn
}
