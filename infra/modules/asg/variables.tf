variable "project" {
  description = "Project name for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
}

variable "ec2_role_name" {
  description = "Name of the EC2 IAM role"
  type        = string
}

variable "ec2_instance_profile" {
  description = "Name of the EC2 instance profile"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the target group"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "ecr_repo_url" {
  description = "URL of the ECR repository"
  type        = string
}

variable "secrets_manager_name" {
  description = "Name of the Secrets Manager secret"
  type        = string
}

variable "alb_sg_id" {
  description = "Security group ID of the ALB"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}
