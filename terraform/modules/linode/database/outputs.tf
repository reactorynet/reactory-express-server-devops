output "id" {
  value = linode_database_postgresql_v2.this.id
}

output "host" {
  description = "Primary endpoint. Private when public_access is false."
  value       = linode_database_postgresql_v2.this.host_primary
}

output "port" {
  value = linode_database_postgresql_v2.this.port
}

output "username" {
  description = <<-EOT
    Generated root account. Linode Managed Databases expose no user management
    through the provider, so unlike DigitalOcean there is no separate,
    independently rotatable application user — the pods hold the root credential.
  EOT
  value       = linode_database_postgresql_v2.this.root_username
  sensitive   = true
}

output "password" {
  value     = linode_database_postgresql_v2.this.root_password
  sensitive = true
}

output "ca_cert" {
  description = "Base64-encoded CA certificate for verifying the TLS connection"
  value       = linode_database_postgresql_v2.this.ca_cert
  sensitive   = true
}
