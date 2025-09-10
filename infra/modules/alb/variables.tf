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

variable "cert_arn" {
  description = "ARN of the SSL certificate"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}
