output "cluster_id" {
  value = linode_lke_cluster.this.id
}

output "cluster_name" {
  value = linode_lke_cluster.this.label
}

output "endpoint" {
  description = "Kubernetes API endpoint, parsed out of the kubeconfig"
  value       = local.cluster_endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA. Public certificate, not sensitive."
  value       = local.cluster_ca_certificate
  sensitive   = true
}

output "cluster_token" {
  description = <<-EOT
    Service account token from the kubeconfig. Long-lived and cluster-admin —
    unlike DigitalOcean, Linode issues no short-lived exec credential, so this is
    how the kubernetes provider authenticates. It lives in state; treat the state
    bucket accordingly.
  EOT
  value       = local.cluster_token
  sensitive   = true
}

output "kubeconfig" {
  description = "Base64-encoded kubeconfig"
  value       = linode_lke_cluster.this.kubeconfig
  sensitive   = true
}

output "vpc_id" {
  value = local.vpc_id
}

output "subnet_id" {
  value = local.subnet_id
}

output "region" {
  value = linode_lke_cluster.this.region
}

output "kubeconfig_command" {
  description = "Write the kubeconfig to disk"
  value       = "linode-cli lke kubeconfig-view ${linode_lke_cluster.this.id} --text --no-headers | base64 --decode > ~/.kube/${linode_lke_cluster.this.label}.yaml"
}
