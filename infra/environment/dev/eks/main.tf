terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 4.0"
    }
  }
  required_version = " >= 1.0.0 , < 2.0.0"
}

provider "aws" {
    region = "us-east-1"

    default_tags {
      tags = {
        Project = "crud-devops-pipeline"
        Environment = "dev"
        ManageBy = "Terraform"
      }
    }
  
}

provider "tls" {} # Required for generating random passwords in the IAM module

data "terraform_remote_state" "networking" {
    backend = "s3"
    config = {
        bucket = "crud-devops-pipeline-bucket-v4"
        key = "dev/networking/terraform.tfstate"
        region = "us-east-1"
    }
  
}

data "terraform_remote_state" "data" {
    backend = "s3"
    config = {
        bucket = "crud-devops-pipeline-bucket-v4"
        key = "dev/data/terraform.tfstate"
        region = "us-east-1"
    }
  
}

terraform {
  backend "s3" {
    bucket = "crud-devops-pipeline-bucket-v4"
    key = "dev/eks/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "crud-devops-pipeline-v4-locks"
    encrypt = true
    
  }
}

locals {
  name = "crud-devops-pipeline"
  environment = "dev"
}

module "eks" {
    source = "../../../modules/eks"

    project_name = local.name
    environment = local.environment
    vpc_id = data.terraform_remote_state.networking.outputs.vpc_id
    private_subnet_id = data.terraform_remote_state.networking.outputs.private_subnet_ids
    public_subnet_id = data.terraform_remote_state.networking.outputs.public_subnet_ids
    cluster_version = "1.35"
    node_instance_type = "t3.medium"
    node_min_size = 1
    node_max_size = 3
    node_desired_size = 2
    cluster_sg_id = data.terraform_remote_state.networking.outputs.eks_cluster_sg_id
      
}

module "iam" {
    source = "../../../modules/iam"

    project_name = local.name
    environment = local.environment
    oidc_provider_arn = module.eks.oidc_provider_arn
    oidc_provider_url = module.eks.oidc_provider_url
    secret_arn = data.terraform_remote_state.data.outputs.secret_arn
}
