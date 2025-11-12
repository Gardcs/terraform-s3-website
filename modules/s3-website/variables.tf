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