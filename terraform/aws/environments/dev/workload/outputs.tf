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
    ALB hostname from the Ingress status. The AWS Load Balancer Controller creates
    the ALB in response to the Ingress, so this is empty on the apply that creates
    it and populated on the next refresh — wait a minute, then `terraform refresh`.
  EOT
  value       = module.reactory_app.alb_hostname
}

output "api_uri_root" {
  description = "Base URL the server was configured with"
  value       = local.api_uri_root
}

output "acm_certificate_arn" {
  value = module.alb_ingress.acm_certificate_arn
}

output "acm_domain_validation_options" {
  description = "DNS records required for ACM validation; null when no domain is set"
  value       = module.alb_ingress.acm_domain_validation_options
}

output "kubernetes_secret_names" {
  description = "Secrets ESO projects into the namespace"
  value       = module.external_secrets.kubernetes_secret_names
}

output "server_environment_variables" {
  description = <<-EOT
    Every environment variable the server container receives, in declaration
    order. Useful for confirming the app contract without a cluster —
    `terraform output server_environment_variables`.
  EOT
  value       = module.reactory_app.environment_variable_names
}

output "mongoose_uri_template" {
  description = "MONGOOSE as written to the pod spec; credentials remain $(VAR) placeholders"
  value       = module.reactory_app.mongoose_uri_template
}
