terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.18.0"
    }
  }

  backend "s3" {
    bucket         = "aparnauk-resume-tfstate"
    key            = "state/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "aparnauk_resumes_tf_lockid"
  }
}