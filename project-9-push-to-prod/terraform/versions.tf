terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  # Fill bucket/table/region by running scripts/bootstrap.sh, which prints the init command.
  backend "s3" {
    key = "project-9/terraform.tfstate"
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "push-to-prod", ManagedBy = "terraform" }
  }
}
