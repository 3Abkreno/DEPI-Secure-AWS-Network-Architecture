resource "aws_internet_gateway" "prod" {
  vpc_id = aws_vpc.prod.id

  tags = {
    Name = "prod-igw"
  }
}

resource "aws_route_table" "prod_public" {
  vpc_id = aws_vpc.prod.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod.id
  }

  tags = {
    Name = "prod-public-rt"
  }
}

resource "aws_route_table" "prod_app" {
  vpc_id = aws_vpc.prod.id

  tags = {
    Name = "prod-app-rt"
  }
}

resource "aws_route_table" "prod_db" {
  vpc_id = aws_vpc.prod.id

  tags = {
    Name = "prod-db-rt"
  }
}

locals {
  prod_route_tables = {
    public = aws_route_table.prod_public.id
    app    = aws_route_table.prod_app.id
    db     = aws_route_table.prod_db.id
  }
}

resource "aws_route_table_association" "prod" {
  for_each = { for name, s in local.prod_subnets : name => s if !startswith(name, "tgw") }

  subnet_id      = aws_subnet.prod[each.key].id
  route_table_id = local.prod_route_tables[split("-", each.key)[0]]
}

resource "aws_vpc_endpoint" "prod_s3" {
  vpc_id            = aws_vpc.prod.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.prod_app.id]

  tags = {
    Name = "prod-s3-endpoint"
  }
}
