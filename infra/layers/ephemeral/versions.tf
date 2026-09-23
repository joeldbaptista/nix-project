terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial configuration, same bucket as the durable layer but a different key:
  #   terraform init -backend-config="bucket=fortune-tfstate-<account-id>"
  backend "s3" {
    key          = "ephemeral/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

# The provider is configured from variables rather than from the durable
# layer's outputs. A provider argument that depends on a data source is
# evaluated late and produces "configuration not known until apply" errors, so
# remote state feeds resources only.
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      Layer     = "ephemeral"
      ManagedBy = "terraform"
    }
  }
}
