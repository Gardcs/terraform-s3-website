# Legg til i main.tf FØR du sletter de gamle ressursene
moved {
  from = aws_s3_bucket.website
  to   = module.s3_website.aws_s3_bucket.website
}

moved {
  from = aws_s3_bucket_website_configuration.website
  to   = module.s3_website.aws_s3_bucket_website_configuration.website
}

moved {
  from = aws_s3_bucket_public_access_block.website
  to   = module.s3_website.aws_s3_bucket_public_access_block.website
}

moved {
  from = aws_s3_bucket_policy.website
  to   = module.s3_website.aws_s3_bucket_policy.website
}

module "s3_website" {
  source = "./modules/s3-website"

  bucket_name         = "pgr301-practice-run-1"
  website_files_path  = "${path.root}/s3_demo_website/dist"

  tags = {
    Name        = "Crypto Juice Exchange"
    Environment = "Demo"
    ManagedBy   = "Terraform"
  }
}

output "s3_website_url" {
  value       = module.s3_website.website_url
  description = "URL for the S3 hosted website"
}

output "bucket_name" {
  value       = module.s3_website.bucket_name
  description = "Name of the S3 bucket"
}