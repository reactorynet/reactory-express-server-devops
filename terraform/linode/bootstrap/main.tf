# ---------------------------------------------------------------------------
# Layer: bootstrap (Linode) — account-level, applied once.
#
#   terraform -chdir=linode/bootstrap init
#   terraform -chdir=linode/bootstrap apply
#
# Creates the Object Storage bucket every other layer stores its state in.
# Linode Object Storage is S3-compatible, so the standard `s3` backend works
# against it with the AWS-specific validation and checksum steps disabled.
#
# There is no locking backend on Linode, so concurrent applies against the same
# tier will corrupt state. Coordinate, or apply only from CI.
#
# This layer keeps LOCAL state — it creates the bucket remote state lives in.
#
# ---------------------------------------------------------------------------
# CREDENTIALS
#
#   LINODE_TOKEN                Personal access token, for every Linode resource
#   Object Storage access keys  Generated below, or supply an existing pair to
#                               the backend via bin/terraform.sh
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 4.1"
    }
  }
  required_version = ">= 1.8.0"
}

provider "linode" {
  # Reads LINODE_TOKEN from the environment.
}

resource "linode_object_storage_bucket" "tf_state" {
  region = var.object_storage_region
  label  = var.state_bucket_name

  # Object Storage buckets are public-read unless told otherwise, and this one
  # holds Terraform state containing every credential in the deployment.
  acl          = "private"
  cors_enabled = false

  versioning = true

  lifecycle_rule {
    id      = "expire-noncurrent-state-versions"
    enabled = true

    noncurrent_version_expiration {
      days = var.state_version_retention_days
    }

    abort_incomplete_multipart_upload_days = 7
  }

  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Access key scoped to the state bucket only, rather than reusing an
# account-wide Object Storage key.
# ---------------------------------------------------------------------------
resource "linode_object_storage_key" "tf_state" {
  count = var.create_access_key ? 1 : 0

  label = "${var.state_bucket_name}-terraform"

  bucket_access {
    bucket_name = linode_object_storage_bucket.tf_state.label
    region      = var.object_storage_region
    permissions = "read_write"
  }
}
