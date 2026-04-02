resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "viloforge-${var.environment}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "viloforge-${var.environment}-igw"
  }
}

# --- Public subnets ---

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "viloforge-${var.environment}-public-${substr(var.availability_zones[count.index], -1, 1)}"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "viloforge-${var.environment}-public"
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Private subnets ---

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "viloforge-${var.environment}-private-${substr(var.availability_zones[count.index], -1, 1)}"
    Tier = "private"
  }
}

resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "viloforge-${var.environment}-private-${substr(var.availability_zones[count.index], -1, 1)}"
  }
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# --- Data subnets ---

resource "aws_subnet" "data" {
  count = length(var.data_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.data_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "viloforge-${var.environment}-data-${substr(var.availability_zones[count.index], -1, 1)}"
    Tier = "data"
  }
}

resource "aws_route_table" "data" {
  count = length(var.data_subnet_cidrs)

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "viloforge-${var.environment}-data-${substr(var.availability_zones[count.index], -1, 1)}"
  }
}

resource "aws_route_table_association" "data" {
  count = length(var.data_subnet_cidrs)

  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data[count.index].id
}

# --- DB subnet group (for future RDS) ---

resource "aws_db_subnet_group" "main" {
  name       = "viloforge-${var.environment}-data"
  subnet_ids = aws_subnet.data[*].id

  tags = {
    Name = "viloforge-${var.environment}-data"
  }
}

# --- VPC Endpoints (free gateway endpoints) ---

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id,
    aws_route_table.data[*].id,
  )

  tags = {
    Name = "viloforge-${var.environment}-s3"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.dynamodb"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id,
    aws_route_table.data[*].id,
  )

  tags = {
    Name = "viloforge-${var.environment}-dynamodb"
  }
}

data "aws_region" "current" {}
