output "cluster_id" {
  description = "Cluster UUID — also the value database firewall rules of type k8s take"
  value       = digitalocean_kubernetes_cluster.this.id
}

output "cluster_name" {
  value = digitalocean_kubernetes_cluster.this.name
}

output "endpoint" {
  description = "Kubernetes API endpoint"
  value       = digitalocean_kubernetes_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA. Public certificate, not sensitive."
  value       = digitalocean_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
}

output "vpc_uuid" {
  description = "VPC the cluster runs in; managed databases must join the same one to be reachable privately"
  value       = local.vpc_uuid
}

output "region" {
  value = digitalocean_kubernetes_cluster.this.region
}

output "kubeconfig_command" {
  value = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.this.name}"
}

output "urn" {
  description = "DigitalOcean URN, for adding the cluster to a project"
  value       = digitalocean_kubernetes_cluster.this.urn
}
