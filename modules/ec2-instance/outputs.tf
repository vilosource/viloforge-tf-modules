output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.main.id
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_instance.main.private_ip
}

output "public_ip" {
  description = "Elastic IP (if associated) or instance public IP"
  value       = var.associate_eip ? aws_eip.main[0].public_ip : aws_instance.main.public_ip
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.instance.id
}
