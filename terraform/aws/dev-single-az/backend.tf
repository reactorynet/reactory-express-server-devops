terraform {
  backend "s3" {
    # Fill these in after running state_bootstrap, or override with:
    #   terraform init -backend-config="bucket=<your-bucket>"
    bucket         = "reactory-terraform-state"
    key            = "dev-single-az/terraform.tfstate"
    region         = "us-west-1"
    dynamodb_table = "reactory-terraform-lock"
    encrypt        = true
  }
}
