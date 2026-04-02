output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "data_subnet_ids" {
  description = "Data subnet IDs"
  value       = aws_subnet.data[*].id
}

output "db_subnet_group_name" {
  description = "DB subnet group name for RDS"
  value       = aws_db_subnet_group.main.name
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}
