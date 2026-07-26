# ---------------------------------------------------------------------------
# Layer: bootstrap — account-level, shared by every environment.
#
# Run ONCE per AWS account, before any environment:
#   terraform -chdir=aws/bootstrap init
#   terraform -chdir=aws/bootstrap apply
#
# Creates:
#   - the S3 bucket and DynamoDB table that hold every other layer's state
#   - the shared ECR registry
#
# Why ECR belongs here rather than in an environment:
#
#   The repository names are not environment-scoped, so an environment-owned
#   registry means dev and production race for the same two repositories —
#   whichever applies second fails with RepositoryAlreadyExists, and a dev
#   teardown with force_delete could remove images production is running.
#
#   Sharing it also enables the promotion model the pipeline expects: build and
#   push an image once, then promote that same digest through dev -> staging ->
#   production by moving the image_tag forward. Nothing rebuilds per environment,
#   so what reaches production is the artifact that was tested.
#
# This layer keeps LOCAL state. It creates the bucket that remote state lives in,
# so it cannot store its own state there. Commit bootstrap/terraform.tfstate to a
# private location or re-import if lost — it holds only the bucket, table and
# repositories, all of which are trivially importable.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
  required_version = ">= 1.8.0"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project   = var.project
    ManagedBy = "terraform"
    Layer     = "bootstrap"
    Scope     = "account-shared"
  }
}

# ---------------------------------------------------------------------------
# Terraform state backend
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Purpose = "terraform-state"
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# State files hold resource attributes; versioning keeps every prior copy, so
# expire noncurrent versions rather than retaining them indefinitely.
resource "aws_s3_bucket_lifecycle_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    id     = "expire-noncurrent-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.state_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.tf_state]
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Purpose = "terraform-state-lock"
  }
}

# ---------------------------------------------------------------------------
# Shared container registry
# ---------------------------------------------------------------------------
module "ecr" {
  source = "../modules/ecr"

  repository_prefix        = var.ecr_repository_prefix
  max_image_count          = var.ecr_max_image_count
  allowed_pull_account_ids = var.ecr_allowed_pull_account_ids

  # Never true for a shared registry — see the module's variable docs.
  force_delete = false

  tags = local.common_tags
}
