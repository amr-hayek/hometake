variable "project" {
  description = "Project name for resource naming"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "ecr_repo_arn" {
  description = "ARN of the ECR repository"
  type        = string
}

variable "secrets_manager_name" {
  description = "Name of the Secrets Manager secret"
  type        = string
}
