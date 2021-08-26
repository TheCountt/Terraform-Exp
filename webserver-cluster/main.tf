# provider "aws" { region = "us-west-1" }

data "aws_vpc" "default" {
  default = true
}

locals {
  http_port = 80
  any_port = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips = ["0.0.0.0/0"]
}

resource "aws_security_group" "instance" {
    name = "${var.cluster_name}-instance"

    ingress {
        from_port   = local.any_port
        to_port     = local.any_port
        protocol    = local.any_protocol
        cidr_blocks = local.all_ips
    }
}

resource "aws_instance" "example" {
    ami = var.ami
    instance_type = var.instance_type
    vpc_security_group_ids = [aws_security_group.instance.id]
    user_data = filebase64("example.sh")
    tags = { 
        Name = "${var.cluster_name}-example" }
    }

# ALB TF
resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-alb" 
}

resource "aws_security_group_rule" "inbound_http" {
  from_port         = local.http_port
  protocol          = local.tcp_protocol
  security_group_id = aws_security_group.alb.id
  to_port           = local.http_port
  type              = "ingress"
  cidr_blocks       = local.all_ips
}

resource "aws_security_group_rule" "outbound_all" {
  from_port         = local.any_port
  protocol          = local.any_protocol
  security_group_id = aws_security_group.alb.id
  to_port           = local.any_port
  type              = "egress"
  cidr_blocks       = local.all_ips
}

# Create Internet facing alb
resource "aws_lb" "example" {
  name = "${var.cluster_name}-alb"
  internal = false
  security_groups = [aws_security_group.alb.id]
  subnets = data.aws_subnet_ids.default.ids
  tags = {
    Name = "${var.cluster_name}-alb"
  }
  ip_address_type    = "ipv4"
  load_balancer_type = "application"
}

# Create a Target Group
resource "aws_lb_target_group" "asg" {
  health_check {
    interval            = 16
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  name        = "${var.cluster_name}-example"
  port        = local.http_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
}

# Create a Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = local.http_port
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = "404"
    }
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

# ASG TF
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
  }

resource "aws_launch_configuration" "example" {
  image_id = var.ami
  instance_type = var.instance_type
  security_groups = [aws_security_group.instance.id]
  user_data = data.template_file.user_data.rendered
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier  = data.aws_subnet_ids.default.ids
  target_group_arns    = [aws_lb_target_group.asg.arn]
  health_check_type    = "ELB"
  min_size             = var.min_size
  max_size             = var.max_size

  tag {
    key = "Name"
    value = var.cluster_name
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.custom_tags

    content {
      key = tag.key
      value = tag.value
      propagate_at_launch = true
    }
  }
}

data "template_file" "user_data" {
  template = filebase64("${path.module}/example.sh")
  vars = {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  }
}

// Testing out Terraform Cloud
resource "aws_lb_listener" "asg" {
  listener   = aws_lb_listener.http.arn
  priority   = 100
  condition {
    field  = "path-pattern"
    values = ["*"]
  }
  action {
    type             = "forward"
    target_group_arn = aws.lb_target_group.asg.arn
  }
}

terraform {
  backend "s3" {
    key = "module/services/webserver-cluster/terraform.tfstate"
  }
}

data "terraform_remote_state" "db" {
  backend = "s3"

  config   = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = var.db_remote_state_region
   }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_utilization" {
  alarm_name = "${var.cluster_name}-high-cpu-utilization"
  namespace = "AWS/EC2"
  metric_name = "CPUUtilization"
  dimensions = {
    "AutoscalingGroupName" = "aws_autoscaling_group.example.name"
  }
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 1
  period = 300
  statistic = "Average"
  threshold = 90
  unit = "Count"
}

resource "aws_cloudwatch_metric_alarm" "low_cpu_credit_balance" {
  count = format("%.1s", var.instance_type) == "t" ? 1 : 0
  alarm_name = "${var.cluster_name}-low-cpu-credit-balance"
  namespace = "AWS/EC2"
  metric_name = "CPUCreditBalance"
  dimensions = {
    "AutoscalingGroupName" = "aws_autoscaling_group.example.name"
  }
  comparison_operator = "LessThanThreshold"
  evaluation_periods = 1
  period = 300
  statistic = "Minimum"
  threshold = 10
  unit = "Count"
}
