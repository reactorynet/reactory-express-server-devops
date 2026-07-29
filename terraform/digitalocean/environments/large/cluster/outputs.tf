# ---------------------------------------------------------------------------
# Consumed by the workload layer. Same shape across all three tiers — every
# managed endpoint is populated at this tier.
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
  value = module.doks.cluster_ca_certificate
}

output "vpc_uuid" {
  value = module.doks.vpc_uuid
}

output "kubeconfig_command" {
  value = module.doks.kubeconfig_command
}

# --- Managed PostgreSQL ----------------------------------------------------
output "postgres_host" {
  value = module.postgres.host
}

output "postgres_port" {
  value = module.postgres.port
}

output "postgres_database" {
  value = module.postgres.database_name
}

output "postgres_username" {
  value     = module.postgres.username
  sensitive = true
}

output "postgres_password" {
  value     = module.postgres.password
  sensitive = true
}

# --- Managed MongoDB -------------------------------------------------------
output "mongodb_host" {
  value = module.mongodb.host
}

output "mongodb_port" {
  value = module.mongodb.port
}

output "mongodb_database" {
  value = module.mongodb.database_name
}

output "mongodb_username" {
  value     = module.mongodb.username
  sensitive = true
}

output "mongodb_password" {
  value     = module.mongodb.password
  sensitive = true
}

# --- Managed Valkey --------------------------------------------------------
output "valkey_host" {
  value = module.valkey.host
}

output "valkey_port" {
  value = module.valkey.port
}

output "valkey_password" {
  value     = module.valkey.password
  sensitive = true
}

# --- Managed OpenSearch ----------------------------------------------------
output "opensearch_host" {
  value = module.opensearch.host
}

output "opensearch_port" {
  value = module.opensearch.port
}

output "opensearch_username" {
  value     = module.opensearch.username
  sensitive = true
}

output "opensearch_password" {
  value     = module.opensearch.password
  sensitive = true
}
