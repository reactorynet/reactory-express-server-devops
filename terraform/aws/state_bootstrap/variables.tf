variable "aws_region" {
  description = "AWS region for the state backend resources"
  type        = string
  default     = "us-west-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "reactory-terraform-lock"
}
