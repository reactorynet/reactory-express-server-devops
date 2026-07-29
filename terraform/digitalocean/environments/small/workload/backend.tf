# Partial backend configuration.
#
# Spaces is S3-compatible, so the s3 backend works against it. The AWS-specific
# validation and checksum steps have to be switched off, and `region` is a
# required field the backend never actually uses when a custom endpoint is set.
#
# bucket and the endpoint come from digitalocean/bootstrap, supplied at init by
# bin/terraform.sh from TF_STATE_BUCKET and TF_STATE_ENDPOINT.
#
# NOTE: Spaces has no locking backend, so concurrent applies WILL corrupt state.
terraform {
  backend "s3" {
    key    = "digitalocean/small/workload/terraform.tfstate"
    region = "us-east-1"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = false
  }
}
