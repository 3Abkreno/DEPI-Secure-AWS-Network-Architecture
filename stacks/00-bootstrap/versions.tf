# Bootstrap keeps LOCAL state on purpose: it creates the bucket the other stacks use.
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Project   = "secure-net"
      Stack     = "00-bootstrap"
      ManagedBy = "terraform"
    }
  }
}
