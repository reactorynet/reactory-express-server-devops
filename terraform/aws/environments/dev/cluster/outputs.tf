# ---------------------------------------------------------------------------
# Outputs consumed by the workload layer via terraform_remote_state.
#
# Adding or renaming anything here is a breaking change for
# environments/dev/workload — keep the shape identical across all environments
# so the workload layers stay interchangeable.
# ---------------------------------------------------------------------------

output "aws_region" {
  value = var.aws_region
}

output "environment" {
  value = var.environment
}

output "project" {
  value = var.project
}

# --- Cluster ---------------------------------------------------------------
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA. Not sensitive — it is a public certificate."
  value       = module.eks.cluster_ca_certificate
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  value = module.eks.oidc_provider_url
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# --- Network ---------------------------------------------------------------
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr" {
  value = module.vpc.vpc_cidr
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

# --- Data services ---------------------------------------------------------
# Dev runs MongoDB and PostgreSQL in-cluster, so there are no managed endpoints
# for them. The workload layer treats a null endpoint as "self-hosted".
output "mongodb_endpoint" {
  description = "Managed DocumentDB endpoint, or null when self-hosted in-cluster"
  value       = null
}

output "mongodb_port" {
  value = null
}

output "mongodb_reader_endpoint" {
  description = "DocumentDB reader endpoint; null in dev — a single pod has no reader"
  value       = null
}

output "postgres_endpoint" {
  description = "Managed Aurora endpoint, or null when self-hosted in-cluster"
  value       = null
}

output "postgres_port" {
  value = null
}

output "postgres_reader_endpoint" {
  description = "Aurora reader endpoint; null in dev — a single pod has no reader"
  value       = null
}

output "opensearch_endpoint" {
  description = "Managed OpenSearch endpoint, or null when using in-cluster Meilisearch"
  value       = null
}

output "opensearch_dashboard_endpoint" {
  description = "OpenSearch Dashboards URL; null in dev, which uses Meilisearch"
  value       = null
}

output "valkey_endpoint" {
  value = module.valkey.primary_endpoint
}

output "valkey_port" {
  value = module.valkey.port
}

# --- Secrets ---------------------------------------------------------------
output "secret_names" {
  description = "Service name to Secrets Manager secret name"
  value       = module.secrets_manager.secret_names
}

output "enabled_secrets" {
  value = module.secrets_manager.enabled_secrets
}

output "eso_role_arn" {
  value = module.secrets_manager.eso_role_arn
}

output "eso_namespace" {
  value = module.secrets_manager.eso_namespace
}

output "eso_service_account" {
  value = module.secrets_manager.eso_service_account
}
