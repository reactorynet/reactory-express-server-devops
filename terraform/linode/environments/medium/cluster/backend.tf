# Partial backend configuration.
#
# Linode Object Storage is S3-compatible, so the s3 backend works against it
# with the AWS-specific validation and checksum steps switched off. `region` is
# required by the backend but unused once a custom endpoint is set.
#
# NOTE: Linode has no locking backend, so concurrent applies WILL corrupt state.
terraform {
  backend "s3" {
    key    = "linode/medium/cluster/terraform.tfstate"
    region = "us-east-1"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
