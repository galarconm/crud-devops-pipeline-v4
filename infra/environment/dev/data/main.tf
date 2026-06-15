terraform {
  required_version = " >= 1.0.0 , < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}


terraform {
  backend "s3" {
    bucket         = "crud-devops-pipeline-bucket-v4"
    key            = "dev/data/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "crud-devops-pipeline-v4-locks"
    encrypt        = true

  }
}

locals {
  name        = "crud-devops-pipeline"
  environment = "dev"
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



data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "crud-devops-pipeline-bucket-v4"
    key    = "dev/networking/terraform.tfstate"
    region = "us-east-1"
  }

}

module "rds" {
  source = "../../../modules/rds"

  project_name      = local.name
  environment       = local.environment
  subnets_ids       = data.terraform_remote_state.networking.outputs.private_subnet_ids
  security_group_id = data.terraform_remote_state.networking.outputs.rds_sg_id
  db_username       = "crudadmin"
  db_password       = var.db_password
  db_name           = "cruddb"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
}

module "secrets" {
  source = "../../../modules/secrets"

  project_name = local.name
  environment  = local.environment
  db_username  = "crudadmin"
  db_password  = var.db_password
  db_host      = module.rds.endpoint
  db_name      = "cruddb"

}