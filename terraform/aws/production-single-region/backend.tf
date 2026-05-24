terraform {
  backend "s3" {
    bucket         = "reactory-terraform-state"
    key            = "production-single-region/terraform.tfstate"
    region         = "us-west-1"
    dynamodb_table = "reactory-terraform-lock"
    encrypt        = true
  }
}
