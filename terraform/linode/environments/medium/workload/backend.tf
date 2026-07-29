# Partial backend configuration — see ../cluster/backend.tf for the rationale.
terraform {
  backend "s3" {
    key    = "linode/medium/workload/terraform.tfstate"
    region = "us-east-1"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
