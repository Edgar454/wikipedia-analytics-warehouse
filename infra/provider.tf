terraform {

  required_version = ">= 1.6"

  backend "s3" {
    bucket       = "edgar-mevaa-terraform-state"
    key          = "wikipedia-analysis/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


provider "aws" {
  region = var.region
}