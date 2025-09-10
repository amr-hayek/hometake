output "cert_arn" {
  description = "ARN of the validated certificate"
  value       = aws_acm_certificate_validation.cert.certificate_arn
}

output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.zone.zone_id
}
