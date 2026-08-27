terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }

  }

  required_version = ">= 1.0.0 , < 2.0.0"
}

terraform {
  backend "s3" {
    bucket         = "crud-devops-pipeline-bucket-v4"
    key            = "dev/addons/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "crud-devops-pipeline-v4-locks"
    encrypt        = true

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

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "crud-devops-pipeline-bucket-v4"
    key    = "dev/eks/terraform.tfstate"
    region = "us-east-1"
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

module "eks_addons" {
  source = "../../../modules/eks-addons"

  project_name      = local.name
  environment       = local.environment
  cluster_name      = data.terraform_remote_state.eks.outputs.cluster_name
  oidc_provider_arn = data.terraform_remote_state.eks.outputs.oidc_provider_arn
  oidc_provider_url = data.terraform_remote_state.eks.outputs.oidc_provider_url
}

locals {
  eniconfig_azs = zipmap(
    ["us-east-1a", "us-east-1b"],
    data.terraform_remote_state.networking.outputs.ekspods_subnet_ids
  )
}

resource "local_file" "eniconfig" {
  filename = "${path.module}/generated/eniconfig.yaml"
  content = templatefile("${path.module}/eniconfig.yaml.tpl", {
    az_subnets = local.eniconfig_azs
    node_sg_id = data.terraform_remote_state.networking.outputs.eks_nodes_sg_id
  })
}