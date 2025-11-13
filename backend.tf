terraform {
  backend "s3" {
    bucket         = "g25gcs-terraform-state"  # Samme som i backend-setup.tf
    key            = "website/terraform.tfstate"
    region         = "eu-west-1"  # Din region
    dynamodb_table = "g25gcs-terraform-state-locks"  # Samme som i backend-setup.tf
    encrypt        = true
  }
}