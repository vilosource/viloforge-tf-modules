module "instance" {
  source = "../ec2-instance"

  name              = var.name
  instance_type     = var.instance_type
  subnet_id         = var.subnet_id
  vpc_id            = var.vpc_id
  key_name          = var.key_name
  associate_eip     = true
  source_dest_check = false # Required for packet forwarding between peers

  ingress_rules = concat(
    [
      {
        from_port   = var.wg_port
        to_port     = var.wg_port
        protocol    = "udp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "WireGuard tunnel"
      },
      {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [var.wg_cidr]
        description = "SSH via WireGuard only"
      },
    ],
    var.extra_ingress_rules,
  )

  tags = merge(var.tags, {
    Role = "wireguard"
  })
}

# EC2 auto-recovery alarm
resource "aws_cloudwatch_metric_alarm" "auto_recovery" {
  alarm_name          = "${var.name}-auto-recovery"
  alarm_description   = "Auto-recover ${var.name} on system status check failure"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    InstanceId = module.instance.instance_id
  }

  alarm_actions = [
    "arn:aws:automate:${data.aws_region.current.name}:ec2:recover"
  ]

  tags = {
    Name = "${var.name}-auto-recovery"
  }
}

data "aws_region" "current" {}
