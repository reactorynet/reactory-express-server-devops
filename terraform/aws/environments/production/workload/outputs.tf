output "namespace" {
  value = kubernetes_namespace.reactory.metadata[0].name
}

output "cluster_name" {
  value = local.cluster.cluster_name
}

output "kubeconfig_command" {
  value = local.cluster.kubeconfig_command
}

output "alb_dns_name" {
  description = <<-EOT
    ALB hostname from the Ingress status. Empty on the apply that creates the
    Ingress and populated on the next refresh — point the Route 53 record here.
  EOT
  value       = module.reactory_app.alb_hostname
}

output "api_uri_root" {
  value = local.api_uri_root
}

output "acm_certificate_arn" {
  value = module.alb_ingress.acm_certificate_arn
}

output "acm_domain_validation_options" {
  description = <<-EOT
    DNS records that must exist before the ACM certificate validates. Without
    them the certificate stays pending and the HTTPS listener never comes up.
  EOT
  value       = module.alb_ingress.acm_domain_validation_options
}

output "kubernetes_secret_names" {
  value = module.external_secrets.kubernetes_secret_names
}

output "server_environment_variables" {
  description = "Every environment variable the server container receives, in declaration order"
  value       = module.reactory_app.environment_variable_names
}

output "mongoose_uri_template" {
  description = "MONGOOSE as written to the pod spec; credentials remain $(VAR) placeholders"
  value       = module.reactory_app.mongoose_uri_template
}

output "opensearch_dashboard_endpoint" {
  value = local.cluster.opensearch_dashboard_endpoint
}
