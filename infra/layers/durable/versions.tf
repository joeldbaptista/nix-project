terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial configuration. The bucket name contains the account ID, so it is
  # supplied at init time:
  #   terraform init -backend-config="bucket=fortune-tfstate-<account-id>"
  backend "s3" {
    key          = "durable/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      Layer     = "durable"
      ManagedBy = "terraform"
    }
  }
}
