output "state_bucket_name" {
  value = digitalocean_spaces_bucket.tf_state.name
}

output "state_bucket_region" {
  value = digitalocean_spaces_bucket.tf_state.region
}

output "state_endpoint" {
  description = "S3-compatible endpoint for the backend config"
  value       = "https://${digitalocean_spaces_bucket.tf_state.region}.digitaloceanspaces.com"
}

output "backend_config" {
  description = <<-EOT
    -backend-config arguments for every other layer. bin/terraform.sh supplies
    these from the environment file; this output is for manual invocations.
  EOT
  value = join(" ", [
    "-backend-config=bucket=${digitalocean_spaces_bucket.tf_state.name}",
    "-backend-config=endpoints={s3=\"https://${digitalocean_spaces_bucket.tf_state.region}.digitaloceanspaces.com\"}",
    "-backend-config=region=us-east-1",
  ])
}
