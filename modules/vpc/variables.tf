variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.11.0.0/20"
}

variable "environment" {
  description = "Environment name (e.g., prod, dev)"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.11.0.0/24", "10.11.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.11.2.0/24", "10.11.3.0/24"]
}

variable "data_subnet_cidrs" {
  description = "CIDR blocks for data subnets (one per AZ)"
  type        = list(string)
  default     = ["10.11.4.0/24", "10.11.5.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["eu-north-1a", "eu-north-1b"]
}
