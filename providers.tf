terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
  default_tags {
    tags = {
      owner = "g25gcs"
    }
  }
}

# Alias provider for us-east-1
# Nødvendig for CloudFront ACM-sertifikater senere i oppgaven
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
  default_tags {
    tags = {
      owner = "g25gcs"
    }
  }
}