terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State lives in an S3 bucket this configuration deliberately does NOT manage
  # (see infra/README.md for the one-time bootstrap). A config that manages its
  # own state store is a `tofu destroy` trap and a circular bootstrap.
  #
  # Backend blocks are read before the rest of the configuration is evaluated,
  # so every value MUST be a literal — `profile = var.aws_profile` is a parse
  # error. `profile` is required: the backend does not inherit the provider's
  # credentials, and omitting it fails `tofu init` with a confusing
  # "No valid credential sources found" after a 30s metadata-endpoint timeout.
  backend "s3" {
    bucket       = "crisis-clothing-tfstate"
    key          = "infra/terraform.tfstate"
    region       = "us-west-2"
    profile      = "crisis-admin"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "crisisclothing.com"
      Environment = "production"
      ManagedBy   = "opentofu"
      Repo        = "The-North-West-Clothing/crisisclothing.com"
    }
  }
}
