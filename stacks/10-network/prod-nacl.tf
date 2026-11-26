locals {
  prod_app_cidrs = {
    a = { cidr = "10.10.10.0/24", rule = 100 }
    b = { cidr = "10.10.11.0/24", rule = 110 }
  }
  prod_db_cidr = "10.10.20.0/23"
}

resource "aws_network_acl" "prod_db" {
  vpc_id     = aws_vpc.prod.id
  subnet_ids = [aws_subnet.prod["db-a"].id, aws_subnet.prod["db-b"].id]

  tags = {
    Name = "prod-db-nacl"
  }
}

resource "aws_network_acl_rule" "db_mysql_in" {
  for_each = local.prod_app_cidrs

  network_acl_id = aws_network_acl.prod_db.id
  rule_number    = each.value.rule
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = 3306
  to_port        = 3306
}

resource "aws_network_acl_rule" "db_replies_out" {
  for_each = local.prod_app_cidrs

  network_acl_id = aws_network_acl.prod_db.id
  rule_number    = each.value.rule
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "db_internal_in" {
  network_acl_id = aws_network_acl.prod_db.id
  rule_number    = 200
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = local.prod_db_cidr
}

resource "aws_network_acl_rule" "db_internal_out" {
  network_acl_id = aws_network_acl.prod_db.id
  rule_number    = 200
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = local.prod_db_cidr
}
