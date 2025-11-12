variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "website_files_path" {
  description = "Path to website files to upload"
  type        = string
}

output "cloudfront_url" {
  description = "CloudFront distribution URL (HTTPS enabled)"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

# Data source - henter informasjon om en eksisterende hosted zone
data "aws_route53_zone" "main" {
  zone_id = "Z09151061LZNRB9E4BYEL"  # thecloudcollege.com
}

# Resource - oppretter en ny DNS-record i den eksisterende zonen
resource "aws_route53_record" "website" {
  zone_id = data.aws_route53_zone.main.zone_id  # Bruker data fra data source
  name    = "${var.subdomain}.thecloudcollege.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

output "cloudfront_domain" {
  description = "CloudFront domain name"
  value       = aws_cloudfront_distribution.website.domain_name
}   

variable "student_name" {
  description = "Your name for the subdomain (e.g., 'glenn' becomes glenn.thecloudcollege.com)"
  type        = string
  default     = "glenn"
}