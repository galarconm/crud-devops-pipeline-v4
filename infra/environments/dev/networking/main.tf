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

  project_name                 = local.name
  environment                  = local.environment
  vpc_cidr_block               = "10.0.0.0/16"
  vpc_ipv4_cidr_block          = "10.1.0.0/16"
  availability_zones           = ["us-east-1a", "us-east-1b"]
  frontend_subnet_cidrs        = ["10.0.1.0/24", "10.0.2.0/24"]
  middleware_subnet_cidrs      = ["10.0.3.0/24", "10.0.4.0/24"]
  data_subnet_cidrs            = ["10.0.5.0/24", "10.0.6.0/24"]
  transit_gateway_subnet_cidrs = ["10.0.7.0/24", "10.0.8.0/24"]
  egress_subnet_cidr           = "10.0.9.0/24"
  ekswork_subnet_cidrs         = ["10.0.11.0/24", "10.0.12.0/24"]
  ekspods_subnet_cidrs         = ["10.1.1.0/24", "10.1.2.0/24"]
  cluster_name                 = "crud-devops-pipeline-dev"

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

module "vpc_endpoints" {
  source = "../../../modules/vpc-endpoints"

  project_name          = local.name
  environment           = local.environment
  vpc_id                = module.networking.vpc_id
  middleware_subnet_ids = module.networking.middleware_subnet_ids
  gateway_route_table_ids = concat(
    [
      module.networking.front_route_table_id,
      module.networking.middleware_route_table_id,
      module.networking.data_route_table_id,
    ],
    module.networking.eks_route_table_ids
  )
  allowed_security_group_ids = [
    module.sg.eks_nodes_sg_id,
    module.sg.eks_cluster_sg_id,
  ]
}


# trigger infra Sat 20 Jun 2026 06:44:20 PM CEST
# trigger infra Mon 03 Aug 2026 03:12:25 PM CEST
# trigger infra Tue 04 Aug 2026 02:36:40 PM CEST
