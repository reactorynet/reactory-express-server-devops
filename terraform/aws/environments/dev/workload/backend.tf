# Partial backend configuration — see ../cluster/backend.tf for the rationale
# and the -backend-config arguments.
terraform {
  backend "s3" {
    key     = "dev/workload/terraform.tfstate"
    encrypt = true
  }
}
