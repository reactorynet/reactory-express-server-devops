output "state_bucket_name" {
  value = linode_object_storage_bucket.tf_state.label
}

output "state_bucket_region" {
  value = linode_object_storage_bucket.tf_state.region
}

output "state_endpoint" {
  description = "S3-compatible endpoint for the backend config"
  value       = "https://${linode_object_storage_bucket.tf_state.region}.linodeobjects.com"
}

output "state_access_key" {
  description = "Access key scoped to the state bucket; use as AWS_ACCESS_KEY_ID for the backend"
  value       = var.create_access_key ? linode_object_storage_key.tf_state[0].access_key : null
  sensitive   = true
}

output "state_secret_key" {
  description = "Use as AWS_SECRET_ACCESS_KEY for the backend"
  value       = var.create_access_key ? linode_object_storage_key.tf_state[0].secret_key : null
  sensitive   = true
}
