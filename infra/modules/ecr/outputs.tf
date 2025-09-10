output "repo_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.repo.repository_url
}

output "repo_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.repo.arn
}

output "repo_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.repo.name
}
