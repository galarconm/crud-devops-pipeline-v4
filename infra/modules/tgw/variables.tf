variable "project_name" {
  description = "The name of the project, used for tagging resources"
  type        = string

}

variable "environment" {
  description = "The environment for the resources"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "tgwattch_subnet_ids" {
  description = "List of subnet IDs for the transit gateway attachment"
  type        = list(string)
}

variable "front_route_table_id" {
  description = "The ID of the route table for frontend subnets"
  type        = string
}

variable "middleware_route_table_id" {
  description = "The ID of the route table for middleware subnets"
  type        = string
}

variable "data_route_table_id" {
  description = "The ID of the route table for data subnets"
  type        = string
}

variable "tgw_destination_cidr_block" {
  description = "The CIDR block for the transit gateway destination"
  type        = string
}