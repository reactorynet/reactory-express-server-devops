output "lbc_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller"
  value       = aws_iam_role.lbc.arn
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN (null if no domain provided)"
  value       = var.domain_name != "" ? aws_acm_certificate.this[0].arn : null
}

output "acm_domain_validation_options" {
  description = "DNS validation records for the ACM certificate"
  value       = var.domain_name != "" ? aws_acm_certificate.this[0].domain_validation_options : null
}
