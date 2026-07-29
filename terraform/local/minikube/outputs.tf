output "namespace" {
  value = kubernetes_namespace.reactory.metadata[0].name
}

output "ingress_host" {
  value = var.ingress_host
}

output "api_uri_root" {
  value = local.api_uri_root
}

output "server_environment_variables" {
  description = <<-EOT
    Every environment variable the server container receives, in declaration
    order — the same list the cloud tiers produce, which is the point of running
    the shared modules locally.
  EOT
  value       = module.reactory_app.environment_variable_names
}

output "mongoose_uri_template" {
  description = "MONGOOSE as written to the pod spec; credentials remain $(VAR) placeholders"
  value       = module.reactory_app.mongoose_uri_template
}

output "kubernetes_secret_names" {
  value = module.app_secrets.kubernetes_secret_names
}

output "port_forward_hints" {
  description = "Reach services without the ingress"
  value = {
    express_server = "kubectl -n ${kubernetes_namespace.reactory.metadata[0].name} port-forward svc/reactory-express-server 4000:4000"
    pwa_client     = "kubectl -n ${kubernetes_namespace.reactory.metadata[0].name} port-forward svc/reactory-pwa-client 8080:80"
    mongodb        = "kubectl -n ${kubernetes_namespace.reactory.metadata[0].name} port-forward svc/mongodb 27017:27017"
    postgres       = "kubectl -n ${kubernetes_namespace.reactory.metadata[0].name} port-forward svc/postgres 5432:5432"
    meilisearch    = "kubectl -n ${kubernetes_namespace.reactory.metadata[0].name} port-forward svc/meilisearch 7700:7700"
  }
}
