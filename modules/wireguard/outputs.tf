output "instance_id" {
  description = "EC2 instance ID"
  value       = module.instance.instance_id
}

output "public_ip" {
  description = "Elastic IP address"
  value       = module.instance.public_ip
}

output "private_ip" {
  description = "Private IP address"
  value       = module.instance.private_ip
}

output "security_group_id" {
  description = "Security group ID"
  value       = module.instance.security_group_id
}

output "iam_role_name" {
  description = "IAM role name for the instance profile"
  value       = module.instance.iam_role_name
}
