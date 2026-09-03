output "express_server_service" {
  description = "In-cluster Service name for the API server"
  value       = kubernetes_service.express_server.metadata[0].name
}

output "pwa_client_service" {
  description = "In-cluster Service name for the PWA client"
  value       = kubernetes_service.pwa_client.metadata[0].name
}

output "express_server_endpoint" {
  description = "Cluster-internal base URL for the API server"
  value       = "http://${kubernetes_service.express_server.metadata[0].name}.${var.namespace}.svc.cluster.local:${var.api_port}"
}

output "web_domain" {
  description = "Resolved Web Client public domain"
  value       = local.web_domain
}

output "api_domain" {
  description = "Resolved API Backend public domain"
  value       = local.api_domain
}

output "is_dual_domain" {
  description = "Whether dual-domain topology is active"
  value       = local.is_dual_domain
}

output "alb_hostname" {
  description = <<-EOT
    ALB hostname taken from the Ingress status if provisioned via AWS Load Balancer Controller.
  EOT
  value = try(
    local.is_dual_domain ? kubernetes_ingress_v1.api[0].status[0].load_balancer[0].ingress[0].hostname : kubernetes_ingress_v1.reactory[0].status[0].load_balancer[0].ingress[0].hostname,
    null
  )
}

output "mongoose_uri_template" {
  description = <<-EOT
    The MONGOOSE value as written into the pod spec. $(MONGO_USER) and
    $(MONGO_PASSWORD) are placeholders expanded by the kubelet, so this is safe
    to display — it contains no credentials.
  EOT
  value       = local.mongoose_uri
}

output "environment_variable_names" {
  description = "Every environment variable name the server container receives, in order"
  value       = [for e in local.server_env : e.name]
}
