output "grafana_service_name" {
  description = "Grafana Kubernetes service name"
  value       = "kube-prometheus-stack-grafana"
}

output "prometheus_service_name" {
  description = "Prometheus Kubernetes service name"
  value       = "kube-prometheus-stack-prometheus"
}

output "jaeger_query_service_name" {
  description = "Jaeger query service name (null if Jaeger not installed)"
  value       = var.install_jaeger ? "jaeger-query" : null
}

output "monitoring_namespace" {
  description = "Monitoring namespace"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}
