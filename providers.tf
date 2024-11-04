provider "aws" {
  alias      = "source"
  region     = "us-east-1"
  access_key = var.source_aws_access_key
  secret_key = var.source_aws_secret_key
}

provider "aws" {
  alias      = "target"
  region     = "us-east-1"
  access_key = var.target_aws_access_key
  secret_key = var.target_aws_secret_key
}