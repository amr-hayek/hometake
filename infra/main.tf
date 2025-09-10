locals {
  tags = {
    Project = var.project
    Environment = "production"
    ManagedBy = "terraform"
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  project = var.project
  tags    = local.tags
}

# VPC Endpoints for SSM already exist in the VPC
# No need to create new ones - using existing endpoints:
# - vpce-00a4dfa5b22086123 (com.amazonaws.us-east-1.ssm)
# - vpce-05d056891e4c12364 (com.amazonaws.us-east-1.ssmmessages)  
# - vpce-0d0ba9284f85b2b4b (com.amazonaws.us-east-1.ec2messages)

# ECR Module
module "ecr" {
  source = "./modules/ecr"
  
  project = var.project
  tags    = local.tags
}

# IAM Module
module "iam" {
  source = "./modules/iam"
  
  project              = var.project
  ecr_repo_arn         = module.ecr.repo_arn
  secrets_manager_name = var.secrets_manager_name
  tags                 = local.tags
}

# ACM Module (SSL Certificate)
module "acm" {
  source = "./modules/acm"
  
  domain_name = var.domain_name
  subdomain   = var.subdomain
  tags        = local.tags
}

# ALB Module
module "alb" {
  source = "./modules/alb"
  
  project        = var.project
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
  cert_arn       = module.acm.cert_arn
  tags           = local.tags
}

# Auto Scaling Group Module
module "asg" {
  source = "./modules/asg"
  
  project               = var.project
  vpc_id                = module.vpc.vpc_id
  public_subnets        = module.vpc.public_subnets
  instance_type         = var.instance_type
  desired_capacity      = var.desired_capacity
  min_size              = var.min_size
  max_size              = var.max_size
  ec2_role_name         = module.iam.ec2_role_name
  ec2_instance_profile  = module.iam.ec2_instance_profile
  target_group_arn      = module.alb.tg_blue_arn
  region                = var.region
  ecr_repo_url          = module.ecr.repo_url
  secrets_manager_name  = var.secrets_manager_name
  alb_sg_id             = module.alb.alb_sg_id
  tags                  = local.tags
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"
  
  project  = var.project
  alb_arn  = module.alb.alb_arn
  tg_arn   = module.alb.tg_blue_arn
  asg_name = module.asg.asg_name
  email_alerts = var.email_alerts
  tags     = local.tags
}

# Route53 record for app subdomain → ALB
resource "aws_route53_record" "app" {
  zone_id = module.acm.zone_id
  name    = "${var.subdomain}.${var.domain_name}"
  type    = "A"
  
  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
