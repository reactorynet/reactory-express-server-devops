# ---------------------------------------------------------------------------
# module: digitalocean/primary/workload — outputs
# ---------------------------------------------------------------------------

output "namespace" {
  description = "Namespace the Reactory workloads live in"
  value       = kubernetes_namespace.reactory.metadata[0].name
}

output "load_balancer_ip" {
  description = <<-EOT
    External IP of the ingress load balancer. Empty on the first apply — re-run
    apply (or refresh) once DigitalOcean has provisioned it.
  EOT
  value       = local.lb_ip
}

output "hostnames" {
  description = "Every public host this layer serves"
  value       = local.served_hosts
}

output "web_domain" {
  value = module.reactory_app.web_domain
}

output "api_domain" {
  value = module.reactory_app.api_domain
}

output "is_dual_domain" {
  description = "True when the web and API ingresses use distinct hosts"
  value       = module.reactory_app.is_dual_domain
}

output "express_server_endpoint" {
  description = "Cluster-internal base URL for the API server"
  value       = module.reactory_app.express_server_endpoint
}

output "dns_records" {
  description = "A records this layer manages (empty until the LB IP is known)"
  value       = { for k, r in digitalocean_record.app : k => r.fqdn }
}

output "telemetry_hostnames" {
  description = "Telemetry endpoints exposed behind the ingress"
  value = var.expose_telemetry ? {
    grafana    = local.fqdn.grafana
    prometheus = local.fqdn.prometheus
    jaeger     = var.install_jaeger ? local.fqdn.jaeger : null
  } : {}
}
