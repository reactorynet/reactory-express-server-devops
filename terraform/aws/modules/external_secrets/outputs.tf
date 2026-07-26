output "kubernetes_secret_names" {
  description = <<-EOT
    Map of service name to the Kubernetes Secret ESO projects it into. Pass these
    into reactory_app rather than hardcoding names — a Secret that nothing
    creates applies cleanly and leaves pods in CreateContainerConfigError.
  EOT
  value = {
    for name in var.enabled_secrets : name => local.secret_schema[name].k8s_name
  }
}

output "secret_keys" {
  description = "Map of service name to the Kubernetes Secret keys projected for it"
  value = {
    for name in var.enabled_secrets : name => keys(local.secret_schema[name].keys)
  }
}

output "cluster_secret_store_name" {
  value       = var.cluster_secret_store_name
  description = "Name of the ClusterSecretStore backed by Secrets Manager"
}

output "release_name" {
  description = "Helm release applying the ClusterSecretStore and ExternalSecrets — depend on this from consumers"
  value       = helm_release.reactory_secrets.name
}
