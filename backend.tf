terraform {
    backend "s3" {
        bucket         = "glenn-pracice-state"
        key            = "website/terraform.tfstate"
        region         = "eu-west-1"
        dynamodb_table = "terraform-state-locks"
        encrypt        = true
    }
}