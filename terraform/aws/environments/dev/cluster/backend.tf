# ---------------------------------------------------------------------------
# Partial backend configuration.
#
# `key` is the layer's identity and belongs in code. bucket, region and
# dynamodb_table are account-specific, so they are supplied at init time:
#
#   terraform init \
#     -backend-config=bucket=<state_bucket_name from aws/bootstrap> \
#     -backend-config=region=us-west-1 \
#     -backend-config=dynamodb_table=reactory-terraform-lock
#
# bin/terraform.sh does this for you from TF_STATE_BUCKET, TF_STATE_REGION and
# TF_STATE_LOCK_TABLE in the environment file.
# ---------------------------------------------------------------------------
terraform {
  backend "s3" {
    key     = "dev/cluster/terraform.tfstate"
    encrypt = true
  }
}
