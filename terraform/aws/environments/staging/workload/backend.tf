# Partial backend configuration — see environments/dev/cluster/backend.tf for the
# rationale and the -backend-config arguments.
terraform {
  backend "s3" {
    key     = "staging/workload/terraform.tfstate"
    encrypt = true
  }
}
