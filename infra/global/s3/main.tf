terraform {

  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "crud_devops_pipeline_bucket" {
  bucket = "crud-devops-pipeline-bucket-v4"
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.crud_devops_pipeline_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.crud_devops_pipeline_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.crud_devops_pipeline_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

resource "aws_dynamodb_table" "crud_devops_pipeline_locks" {
  name         = "crud-devops-pipeline-v4-locks"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "LockID"
    type = "S"
  }

  hash_key = "LockID"
}

#Ejecutar terraform init después de crear el bucket y la tabla DynamoDB para configurar el backend remoto de Terraform
terraform {
  backend "s3" {
    bucket         = "crud-devops-pipeline-bucket-v4"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "crud-devops-pipeline-v4-locks"
    encrypt        = true

  }
}