variable "name" {
  description = "Instance name"
  type        = string
  default     = "wireguard"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Public subnet ID for the WireGuard instance"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "wg_port" {
  description = "WireGuard listen port"
  type        = number
  default     = 51820
}

variable "wg_cidr" {
  description = "WireGuard tunnel CIDR (for SSH access restriction)"
  type        = string
  default     = "10.200.0.0/24"
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
