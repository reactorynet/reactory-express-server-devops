# ---------------------------------------------------------------------------
# Layer: bootstrap (DigitalOcean) — account-level, applied once.
#
#   terraform -chdir=digitalocean/bootstrap init
#   terraform -chdir=digitalocean/bootstrap apply
#
# Creates the Spaces bucket every other layer stores its state in. Spaces is
# S3-compatible, so the standard `s3` backend works against it with the checksum
# and validation options disabled — see any tier's backend.tf.
#
# There is no DynamoDB equivalent on DigitalOcean, so there is no state locking.
# Two people running apply against the same tier simultaneously will corrupt
# state. Coordinate, or run applies only from CI.
#
# This layer keeps LOCAL state — it creates the bucket remote state lives in, so
# it cannot store its own state there.
#
# ---------------------------------------------------------------------------
# CREDENTIALS
#
# Two different ones are needed, and they are not interchangeable:
#   DIGITALOCEAN_TOKEN                      API token, for every DO resource
#   SPACES_ACCESS_KEY_ID / SPACES_SECRET_ACCESS_KEY
#                                           Spaces keys, for the bucket and the
#                                           state backend
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.43"
    }
  }
  required_version = ">= 1.8.0"
}

provider "digitalocean" {
  # token, spaces_access_id and spaces_secret_key are read from
  # DIGITALOCEAN_TOKEN, SPACES_ACCESS_KEY_ID and SPACES_SECRET_ACCESS_KEY.
}

resource "digitalocean_spaces_bucket" "tf_state" {
  name   = var.state_bucket_name
  region = var.spaces_region
  acl    = "private"

  versioning {
    enabled = true
  }

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
