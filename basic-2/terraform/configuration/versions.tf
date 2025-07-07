terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Optional: Configure backend for state management
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "django-microservices/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  # Optional: Add default tags to all resources
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

# Provider for cross-region backup replication
provider "aws" {
  alias  = "replica"
  region = var.aws_region == "us-east-1" ? "us-west-2" : "us-east-1"
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Purpose     = "Backup-Replica"
    }
  }
} 