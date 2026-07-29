output "service_name" {
  value = kubernetes_service.mongodb.metadata[0].name
}

output "host" {
  description = "Cluster-internal DNS name"
  value       = "${kubernetes_service.mongodb.metadata[0].name}.${var.namespace}.svc.cluster.local"
}

output "port" {
  value = 27017
}
