# ---------------------------------------------------------------------------
# Consumed by the workload layer. Same shape across all three tiers.
#
# mongodb, valkey and opensearch are null at EVERY Linode tier: Akamai offers no
# managed equivalent, so those always run as in-cluster pods.
# ---------------------------------------------------------------------------

output "project" {
  value = var.project
}

output "tier" {
  value = var.tier
}

output "region" {
  value = module.lke.region
}

# --- Cluster ---------------------------------------------------------------
output "cluster_id" {
  value = module.lke.cluster_id
}

output "cluster_name" {
  value = module.lke.cluster_name
}

output "cluster_endpoint" {
  value = module.lke.endpoint
}

output "cluster_ca_certificate" {
  value = module.lke.cluster_ca_certificate
}

output "cluster_token" {
  description = "Long-lived service account token; Linode issues no short-lived exec credential"
  value       = module.lke.cluster_token
  sensitive   = true
}

output "vpc_id" {
  value = module.lke.vpc_id
}

output "subnet_id" {
  value = module.lke.subnet_id
}

output "kubeconfig_command" {
  value = module.lke.kubeconfig_command
}

# --- Managed PostgreSQL ----------------------------------------------------
output "postgres_host" {
  value = module.postgres.host
}

output "postgres_port" {
  value = module.postgres.port
}

output "postgres_database" {
  description = "Linode Managed Databases create a default `postgres` database"
  value       = "postgres"
}

output "postgres_username" {
  value     = module.postgres.username
  sensitive = true
}

output "postgres_password" {
  value     = module.postgres.password
  sensitive = true
}

# --- No managed equivalent on Linode ---------------------------------------
output "mongodb_host" {
  value = null
}

output "mongodb_port" {
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
