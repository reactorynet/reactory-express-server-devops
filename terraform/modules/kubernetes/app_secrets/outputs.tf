output "kubernetes_secret_names" {
  description = <<-EOT
    Map of service name to the Kubernetes Secret holding its credentials.
    Deliberately the same shape as modules/aws/external_secrets' output of the
    same name, so reactory_app is wired identically regardless of which
    mechanism created the Secrets.
  EOT
  value = {
    for name in var.enabled_secrets : name => local.candidates[name].k8s_name
  }
}

output "secret_keys" {
  description = "Map of service name to the keys present in its Secret"
  value = {
    for name in var.enabled_secrets : name => keys(local.candidates[name].data)
  }
}

output "registry_secret_name" {
  description = "Name of the docker-registry Secret, or null when no registry_auth was supplied"
  value       = var.registry_auth == null ? null : kubernetes_secret.registry[0].metadata[0].name
}
