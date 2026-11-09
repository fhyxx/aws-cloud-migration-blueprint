terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = var.aws_region
  skip_credentials_validation = var.skip_credentials_validation
  skip_requesting_account_id  = var.skip_requesting_account_id

  default_tags {
    tags = {
      Project     = "clafoke-cloud-migration-blueprint"
      Environment = "portfolio"
      ManagedBy   = "Terraform"
      DataClass   = "synthetic"
    }
  }
}
