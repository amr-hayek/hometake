variable "domain_name" {
  description = "Root domain name"
  type        = string
}

variable "subdomain" {
  description = "Subdomain for the application"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}
