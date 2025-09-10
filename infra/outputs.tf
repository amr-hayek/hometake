output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "app_url" {
  description = "URL of the deployed application"
  value       = "https://${var.subdomain}.${var.domain_name}"
}

output "ecr_repo_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repo_url
}

output "asg_tag_key" {
  description = "Tag key for identifying ASG instances"
  value       = "Project"
}

output "asg_tag_value" {
  description = "Tag value for identifying ASG instances"
  value       = var.project
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${var.project}-dashboard"
}

output "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = module.iam.secrets_manager_arn
}
