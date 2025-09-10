output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.this.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.this.arn
}

output "ec2_sg_id" {
  description = "Security group ID of the EC2 instances"
  value       = aws_security_group.ec2.id
}
