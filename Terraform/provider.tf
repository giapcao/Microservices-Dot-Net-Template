terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.87"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    key     = "terraform/state.tfstate"
    encrypt = true
  }
}


provider "aws" {
  region = var.aws_region  # Use variable to allow switching regions

}
