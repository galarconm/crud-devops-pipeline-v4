variable "project_name" {
  description = "The name of the project for tagging purposes"
  type        = string

}

variable "environment" {
  description = "The environment (e.g., dev, staging, prod) for tagging purposes"
  type        = string

}

variable "vpc_id" {
  description = "The ID of the VPC where security groups will be created"
  type        = string

}

