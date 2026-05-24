output "primary_endpoint" {
  description = "Primary endpoint (single/cluster mode)"
  value = (
    var.mode != "serverless"
    ? (var.mode == "cluster"
      ? aws_elasticache_replication_group.this[0].configuration_endpoint_address
      : aws_elasticache_replication_group.this[0].primary_endpoint_address)
    : aws_elasticache_serverless_cache.this[0].endpoint[0].address
  )
}

output "reader_endpoint" {
  description = "Reader endpoint (single mode with replica, null otherwise)"
  value = (
    var.mode == "single"
    ? aws_elasticache_replication_group.this[0].reader_endpoint_address
    : null
  )
}

output "port" {
  description = "Valkey port"
  value       = 6379
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.valkey.id
}
