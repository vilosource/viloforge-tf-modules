# Latest Ubuntu 24.04 AMI from Canonical — used only when var.ami_id is null
data "aws_ami" "ubuntu" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM role with SSM access for Session Manager
resource "aws_iam_role" "instance" {
  name = "${var.name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.name}-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.instance.name
}

# Security group
resource "aws_security_group" "instance" {
  name_prefix = "${var.name}-"
  vpc_id      = var.vpc_id
  description = "Security group for ${var.name}"

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.name}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 instance
resource "aws_instance" "main" {
  ami                  = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id
  instance_type        = var.instance_type
  subnet_id            = var.subnet_id
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.instance.name
  source_dest_check    = var.source_dest_check

  vpc_security_group_ids = [aws_security_group.instance.id]

  metadata_options {
    http_tokens   = "required" # IMDSv2 enforced
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  tags = merge(var.tags, {
    Name = var.name
  })

  # AMI pin: require explicit ami_id bump (or taint) to replace the instance.
  # Prevents accidental replacement when a newer Canonical image is published.
  lifecycle {
    ignore_changes = [ami]
  }
}

# Elastic IP (optional)
resource "aws_eip" "main" {
  count  = var.associate_eip ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.name}-eip"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_eip_association" "main" {
  count         = var.associate_eip ? 1 : 0
  instance_id   = aws_instance.main.id
  allocation_id = aws_eip.main[0].id
}
