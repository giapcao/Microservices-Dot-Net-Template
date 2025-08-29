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
    bucket         = "microservices-dot-net-template-terraform-state"
    key            = "terraform/state.tfstate"
    region         = "us-east-1"
    dynamodb_table = "microservices-dot-net-template-terraform-locks"
    encrypt        = true
    profile        = "terraform-user"
  }
}


provider "aws" {
  region  = "us-east-1"
  profile = "terraform-user"

}
