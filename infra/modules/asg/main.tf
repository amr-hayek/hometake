# Security Group for EC2 instances
resource "aws_security_group" "ec2" {
  name        = "${var.project}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = var.vpc_id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(var.tags, { 
    Name = "${var.project}-ec2-sg" 
  })
}

# Allow traffic from ALB to EC2
resource "aws_security_group_rule" "from_alb" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ec2.id
  source_security_group_id = var.alb_sg_id
  description              = "Allow traffic from ALB"
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"]
  
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Template for docker-compose.yml
data "template_file" "compose" {
  template = file("${path.root}/../../deploy/docker-compose.yml.tftpl")
  vars = {
    ecr_repo_url = var.ecr_repo_url
    image_tag    = "latest"
    region       = var.region
    instance_id  = "$${instance_id}"
  }
}

# Template for CloudWatch Agent config
data "template_file" "cwagent" {
  template = file("${path.root}/../../deploy/cwagent-config.json.tftpl")
  vars = {
    asg_name    = "${var.project}-asg"
    instance_id = "$${instance_id}"
  }
}

# User data script
locals {
  userdata = base64encode(templatefile("${path.module}/userdata.sh", {
    ecr_repo_url         = var.ecr_repo_url
    region              = var.region
    secrets_manager_name = var.secrets_manager_name
    compose_template    = data.template_file.compose.rendered
    cwagent_template    = data.template_file.cwagent.rendered
  }))
}

# Launch Template
resource "aws_launch_template" "this" {
  name_prefix   = "${var.project}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type
  
  vpc_security_group_ids = [aws_security_group.ec2.id]
  
  iam_instance_profile {
    name = var.ec2_instance_profile
  }
  
  user_data = local.userdata
  
  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, { 
      Name = "${var.project}-ec2" 
    })
  }
  
  tag_specifications {
    resource_type = "volume"
    tags = var.tags
  }
  
  tags = var.tags
}

# Auto Scaling Group
resource "aws_autoscaling_group" "this" {
  name                = "${var.project}-asg"
  vpc_zone_identifier = var.public_subnets
  target_group_arns   = [var.target_group_arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity
  
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Name"
    value               = "${var.project}-asg-instance"
    propagate_at_launch = true
  }
}

# Auto Scaling Policy - Scale Up
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
}

# Auto Scaling Policy - Scale Down
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
}

# Target Tracking Scaling Policy
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.project}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"
  
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
