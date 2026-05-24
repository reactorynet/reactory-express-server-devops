output "cluster_endpoint" {
  description = "Primary (writer) endpoint"
  value       = aws_docdb_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint (load-balanced)"
  value       = aws_docdb_cluster.this.reader_endpoint
}

output "cluster_port" {
  description = "DocumentDB port"
  value       = aws_docdb_cluster.this.port
}

output "security_group_id" {
  description = "DocumentDB security group ID"
  value       = aws_security_group.docdb.id
}

output "connection_string_prefix" {
  description = "MongoDB connection string prefix (password not included)"
  value       = "mongodb://${aws_docdb_cluster.this.master_username}:<password>@${aws_docdb_cluster.this.endpoint}:${aws_docdb_cluster.this.port}/?tls=true&tlsCAFile=rds-combined-ca-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
}
