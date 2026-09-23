output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Ordered by availability zone name, so index 0 is stable across runs."
  value       = [for az in local.azs : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  description = "Ordered by availability zone name, so index 0 is stable across runs."
  value       = [for az in local.azs : aws_subnet.private[az].id]
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}
