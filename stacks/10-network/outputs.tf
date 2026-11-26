output "prod_vpc_id" {
  value = aws_vpc.prod.id
}

output "prod_vpc_cidr" {
  value = aws_vpc.prod.cidr_block
}

output "prod_public_subnet_ids" {
  value = [for name, s in aws_subnet.prod : s.id if startswith(name, "public")]
}

output "prod_app_subnet_ids" {
  value = [for name, s in aws_subnet.prod : s.id if startswith(name, "app")]
}

output "prod_db_subnet_ids" {
  value = [for name, s in aws_subnet.prod : s.id if startswith(name, "db")]
}

output "prod_tgw_subnet_ids" {
  value = [for name, s in aws_subnet.prod : s.id if startswith(name, "tgw")]
}

output "prod_app_route_table_id" {
  value = aws_route_table.prod_app.id
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "app_sg_id" {
  value = aws_security_group.app.id
}

output "db_sg_id" {
  value = aws_security_group.db.id
}
