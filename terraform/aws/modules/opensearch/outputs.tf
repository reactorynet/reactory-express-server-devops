output "endpoint" {
  description = "OpenSearch domain or collection endpoint"
  value = (
    var.mode == "managed"
    ? "https://${aws_opensearch_domain.this[0].endpoint}"
    : aws_opensearchserverless_collection.this[0].collection_endpoint
  )
}

output "dashboard_endpoint" {
  description = "OpenSearch Dashboards (Kibana) endpoint"
  value = (
    var.mode == "managed"
    ? "https://${aws_opensearch_domain.this[0].dashboard_endpoint}"
    : aws_opensearchserverless_collection.this[0].dashboard_endpoint
  )
}

output "domain_arn" {
  description = "ARN of the managed domain or serverless collection"
  value = (
    var.mode == "managed"
    ? aws_opensearch_domain.this[0].arn
    : aws_opensearchserverless_collection.this[0].arn
  )
}

output "security_group_id" {
  description = "Security group ID (managed mode only)"
  value       = var.mode == "managed" ? aws_security_group.opensearch[0].id : null
}
