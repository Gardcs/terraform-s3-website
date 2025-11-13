variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = "bucket-g25gcs"
}

output "s3_website_url" {
  value       = module.s3_website.website_url
  description = "URL for the S3 hosted website"
}

output "bucket_name" {
  value       = module.s3_website.bucket_name
  description = "Name of the S3 bucket"
}

module "s3_website" {
  source = "./modules/s3-website"

  providers = {
    aws           = aws           # Default provider
    aws.us-east-1 = aws.us-east-1 # Aliased provider
  }

  bucket_name = var.bucket_name
  # subdomain   = var.subdomain
}


output "cloudfront_url" {
  value       = module.s3_website.cloudfront_url
  description = "CloudFront URL with HTTPS"
}