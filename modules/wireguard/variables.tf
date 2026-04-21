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

variable "extra_ingress_rules" {
  description = "Additional security-group ingress rules appended to the WireGuard defaults (UDP 51820 + SSH from WG CIDR). Use for things like exposing 443 when the host also runs an nginx reverse proxy for webhook ingress."
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = []
}
