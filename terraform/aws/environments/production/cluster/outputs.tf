# ---------------------------------------------------------------------------
# Outputs consumed by environments/production/workload via terraform_remote_state.
# The shape is identical across dev, staging and production so the workload
# layers stay interchangeable — dev reports null for the managed endpoints it
# does not have.
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
output "mongodb_endpoint" {
  value = module.documentdb.cluster_endpoint
}

output "mongodb_port" {
  value = module.documentdb.cluster_port
}

output "mongodb_reader_endpoint" {
  value = module.documentdb.reader_endpoint
}

output "postgres_endpoint" {
  value = module.rds.cluster_endpoint
}

output "postgres_port" {
  value = module.rds.cluster_port
}

output "postgres_reader_endpoint" {
  value = module.rds.cluster_reader_endpoint
}

output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint, including scheme"
  value       = module.opensearch.endpoint
}

output "opensearch_dashboard_endpoint" {
  value = module.opensearch.dashboard_endpoint
}

output "valkey_endpoint" {
  value = module.valkey.primary_endpoint
}

output "valkey_port" {
  value = module.valkey.port
}

# --- Secrets ---------------------------------------------------------------
output "secret_names" {
  value = module.secrets_manager.secret_names
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
