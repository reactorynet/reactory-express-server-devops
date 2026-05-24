output "service_name" {
  description = "Kubernetes service name for in-cluster access"
  value       = kubernetes_service.meilisearch.metadata[0].name
}

output "service_endpoint" {
  description = "In-cluster endpoint"
  value       = "http://${kubernetes_service.meilisearch.metadata[0].name}.${var.namespace}.svc.cluster.local:7700"
}
