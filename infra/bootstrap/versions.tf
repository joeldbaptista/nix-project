terraform {
  # 1.10 introduced S3 native state locking, which removes the need for a
  # DynamoDB lock table. The layers rely on it, so bootstrap requires it too.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Bootstrap keeps local state on purpose: it creates the bucket that every
  # other layer stores its state in, so it cannot store its own state there.
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "fortune"
      Layer     = "bootstrap"
      ManagedBy = "terraform"
    }
  }
}
