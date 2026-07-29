output "namespace" {
  value = kubernetes_namespace.reactory.metadata[0].name
}

output "cluster_name" {
  value = local.cluster.cluster_name
}

output "kubeconfig_command" {
  value = local.cluster.kubeconfig_command
}

output "load_balancer_ip" {
  description = <<-EOT
    Public IP of the DigitalOcean Load Balancer fronting ingress-nginx. Point
    your DNS A record here.

    Empty on the apply that creates it — provisioning takes a minute or two —
    and populated on the next refresh.
  EOT
  value       = module.ingress_nginx.load_balancer_ingress.ip
}

output "api_uri_root" {
  value = local.api_uri_root
}

output "tls_enabled" {
  value = local.tls_enabled
}

output "cluster_issuer_name" {
  value = module.ingress_nginx.cluster_issuer_name
}

output "kubernetes_secret_names" {
  value = module.app_secrets.kubernetes_secret_names
}

output "server_environment_variables" {
  description = "Every environment variable the server container receives, in declaration order"
  value       = module.reactory_app.environment_variable_names
}

output "mongoose_uri_template" {
  description = "MONGOOSE as written to the pod spec; credentials remain $(VAR) placeholders"
  value       = module.reactory_app.mongoose_uri_template
}

output "postgres_host" {
  description = "Managed PostgreSQL private hostname"
  value       = local.cluster.postgres_host
}

output "valkey_host" {
  description = "Managed Valkey private hostname"
  value       = local.cluster.valkey_host
}
