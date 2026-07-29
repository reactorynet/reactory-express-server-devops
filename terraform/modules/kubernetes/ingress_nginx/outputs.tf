output "ingress_class_name" {
  description = "IngressClass to set on Ingress resources"
  value       = var.ingress_class_name
}

output "namespace" {
  value = var.namespace
}

output "controller_service_name" {
  description = "Name of the LoadBalancer Service fronting the controller"
  value       = "ingress-nginx-controller"
}

output "cluster_issuer_name" {
  description = <<-EOT
    ClusterIssuer to reference from the cert-manager.io/cluster-issuer
    annotation, or null when cert-manager is disabled.
  EOT
  value       = var.enable_cert_manager ? var.cluster_issuer_name : null
}

output "release_name" {
  description = "Helm release name — depend on this from workloads that need ingress to exist"
  value       = helm_release.ingress_nginx.name
}

output "load_balancer_ingress" {
  description = <<-EOT
    The cloud load balancer's address, read back from the controller Service.
    DigitalOcean and Linode both assign an IP rather than a hostname, so `ip` is
    normally the populated field. Point your DNS A record at it.

    Empty on the apply that creates the load balancer — provisioning takes a
    minute or two — and populated on the next refresh.
  EOT
  value = try(
    {
      ip       = data.kubernetes_service.controller.status[0].load_balancer[0].ingress[0].ip
      hostname = data.kubernetes_service.controller.status[0].load_balancer[0].ingress[0].hostname
    },
    { ip = null, hostname = null }
  )
}
