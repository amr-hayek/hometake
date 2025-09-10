variable "project" {
  description = "Project name for resource naming"
  type        = string
  default     = "takehome"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Root domain name in Route53"
  type        = string
}

variable "subdomain" {
  description = "Subdomain for the application"
  type        = string
  default     = "app"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 5
}

variable "secrets_manager_name" {
  description = "Name of AWS Secrets Manager secret for app environment variables"
  type        = string
  default     = "takehome/app"
}

variable "email_alerts" {
  description = "Email address for CloudWatch alerts"
  type        = string
  default     = ""
}
