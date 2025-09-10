# VPC Endpoints for SSM
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.public[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
  
  tags = merge(var.tags, { 
    Name = "${var.project}-ssm-endpoint" 
  })
}

resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.public[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
  
  tags = merge(var.tags, { 
    Name = "${var.project}-ssm-messages-endpoint" 
  })
}

resource "aws_vpc_endpoint" "ec2_messages" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.public[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
  
  tags = merge(var.tags, { 
    Name = "${var.project}-ec2-messages-endpoint" 
  })
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoint" {
  name        = "${var.project}-vpc-endpoint-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.this.id
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(var.tags, { 
    Name = "${var.project}-vpc-endpoint-sg" 
  })
}

# Data source for current region
data "aws_region" "current" {}
