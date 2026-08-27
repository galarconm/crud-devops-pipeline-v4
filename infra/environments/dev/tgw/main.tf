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

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "crud-devops-pipeline-bucket-v4"
    key    = "dev/networking/terraform.tfstate"
    region = "us-east-1"
  }

}

module "tgw" {
  source = "../../../modules/tgw"

  project_name               = local.name
  environment                = local.environment
  vpc_id                     = data.terraform_remote_state.networking.outputs.vpc_id
  tgwattch_subnet_ids        = data.terraform_remote_state.networking.outputs.transit_gateway_subnet_ids
  front_route_table_id       = data.terraform_remote_state.networking.outputs.front_route_table_id
  middleware_route_table_id  = data.terraform_remote_state.networking.outputs.middleware_route_table_id
  data_route_table_id        = data.terraform_remote_state.networking.outputs.data_route_table_id
  tgw_destination_cidr_block = "10.0.0.0/8"



}

terraform {
  backend "s3" {
    bucket         = "crud-devops-pipeline-bucket-v4"
    key            = "dev/tgw/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "crud-devops-pipeline-v4-locks"
    encrypt        = true

  }
}