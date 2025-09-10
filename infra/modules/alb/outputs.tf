output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.this.zone_id
}

output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.this.arn
}

output "alb_sg_id" {
  description = "Security group ID of the load balancer"
  value       = aws_security_group.alb.id
}

output "tg_blue_arn" {
  description = "ARN of the blue target group"
  value       = aws_lb_target_group.blue.arn
}
