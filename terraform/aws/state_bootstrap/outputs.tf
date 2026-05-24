output "state_bucket_name" {
  description = "S3 bucket name — use in each blueprint's backend.tf"
  value       = aws_s3_bucket.tf_state.bucket
}

output "state_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.tf_state.arn
}

output "lock_table_name" {
  description = "DynamoDB lock table name — use in each blueprint's backend.tf"
  value       = aws_dynamodb_table.tf_lock.name
}
