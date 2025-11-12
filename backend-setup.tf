# This file creates the resources needed for Terraform remote state
# Run this FIRST before configuring the backend

data "aws_region" "current" {}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "glenn-pracice-state"  # Bytt til unikt navn

  tags = {
    Name        = "Terraform State"
    Environment = "Infrastructure"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform State Locks"
  }
}

output "backend_config" {
  value = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.terraform_state.id}"
      key            = "website/terraform.tfstate"
      region         = "${data.aws_region.current.name}"
      dynamodb_table = "${aws_dynamodb_table.terraform_locks.id}"
      encrypt        = true
    }
  EOT
  description = "Backend configuration to add to your terraform block"
}