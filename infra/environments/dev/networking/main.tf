terraform {
  required_version = " >= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "crud-devops-pipeline"
      Environment = "dev"
      ManageBy    = "Terraform"
    }
  }

}

locals {
  name        = "crud-devops-pipeline"
  environment = "dev"
}

module "networking" {
  source = "../../../modules/vpc"

  project_name         = local.name
  environment          = local.environment
  vpc_cidr_block       = "192.168.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["192.168.1.0/24", "192.168.2.0/24"]
  private_subnet_cidrs = ["192.168.3.0/24", "192.168.4.0/24"]
  cluster_name         = "crud-devops-pipeline-dev"

}

module "sg" {
  source = "../../../modules/security"

  project_name = local.name
  environment  = local.environment
  vpc_id       = module.networking.vpc_id

}

terraform {
  backend "s3" {
    bucket         = "crud-devops-pipeline-bucket-v4"
    key            = "dev/networking/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "crud-devops-pipeline-v4-locks"
    encrypt        = true

  }
}