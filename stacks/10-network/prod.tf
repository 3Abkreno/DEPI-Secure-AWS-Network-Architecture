locals {
  prod_subnets = {
    public-a = { cidr = "10.10.0.0/24", az = "us-east-1a" }
    public-b = { cidr = "10.10.1.0/24", az = "us-east-1b" }
    app-a    = { cidr = "10.10.10.0/24", az = "us-east-1a" }
    app-b    = { cidr = "10.10.11.0/24", az = "us-east-1b" }
    db-a     = { cidr = "10.10.20.0/24", az = "us-east-1a" }
    db-b     = { cidr = "10.10.21.0/24", az = "us-east-1b" }
    tgw-a    = { cidr = "10.10.255.0/28", az = "us-east-1a" }
    tgw-b    = { cidr = "10.10.255.16/28", az = "us-east-1b" }
  }
}

resource "aws_vpc" "prod" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "prod-vpc"
  }
}

resource "aws_subnet" "prod" {
  for_each = local.prod_subnets

  vpc_id            = aws_vpc.prod.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = "prod-${each.key}"
  }
}
