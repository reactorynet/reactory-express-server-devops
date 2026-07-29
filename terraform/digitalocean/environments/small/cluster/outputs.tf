# ---------------------------------------------------------------------------
# Consumed by the workload layer via terraform_remote_state.
#
# The shape is identical across small, medium and large so the workload layers
# stay interchangeable — this tier reports null for every managed endpoint it
# does not have, exactly as the AWS dev cluster layer does.
# ---------------------------------------------------------------------------

output "project" {
  value = var.project
}

output "tier" {
  value = var.tier
}

output "region" {
  value = module.doks.region
}

# --- Cluster ---------------------------------------------------------------
output "cluster_id" {
  value = module.doks.cluster_id
}

output "cluster_name" {
  value = module.doks.cluster_name
}

output "cluster_endpoint" {
  value = module.doks.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA. Public certificate, not sensitive."
  value       = module.doks.cluster_ca_certificate
}

output "vpc_uuid" {
  value = module.doks.vpc_uuid
}

output "kubeconfig_command" {
  value = module.doks.kubeconfig_command
}

# --- Managed data services -------------------------------------------------
# All null here: this tier runs every data service as a pod.
output "postgres_host" {
  value = null
}

output "postgres_port" {
  value = null
}

output "postgres_database" {
  value = null
}

output "postgres_username" {
  value     = null
  sensitive = true
}

output "postgres_password" {
  value     = null
  sensitive = true
}

output "mongodb_host" {
  value = null
}

output "mongodb_port" {
  value = null
}

output "mongodb_database" {
  value = null
}

output "mongodb_username" {
  value     = null
  sensitive = true
}

output "mongodb_password" {
  value     = null
  sensitive = true
}

output "valkey_host" {
  value = null
}

output "valkey_port" {
  value = null
}

output "valkey_password" {
  value     = null
  sensitive = true
}

output "opensearch_host" {
  value = null
}

output "opensearch_port" {
  value = null
}

output "opensearch_username" {
  value     = null
  sensitive = true
}

output "opensearch_password" {
  value     = null
  sensitive = true
}
