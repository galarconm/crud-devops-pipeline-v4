variable "project_name" {
  description = "The name of the project, used for tagging resources"
  type        = string

}

variable "environment" {
  description = "The environment for the resources"
  type        = string
  default     = "dev"
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones for subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]

}

variable "cluster_name" {
  description = "The name of the EKS cluster, used for tagging resources"
  type        = string

}

variable "vpc_ipv4_cidr_block" {
  description = "The IPv4 CIDR block to associate with the VPC"
  type        = string
}

variable "frontend_subnet_cidrs" {
  description = "List of CIDR blocks for frontend subnets"
  type        = list(string)
}

variable "middleware_subnet_cidrs" {
  description = "List of CIDR blocks for middleware subnets"
  type        = list(string)
}

variable "data_subnet_cidrs" {
  description = "List of CIDR blocks for data subnets"
  type        = list(string)
}

variable "transit_gateway_subnet_cidrs" {
  description = "List of CIDR blocks for transit gateway subnets"
  type        = list(string)
}

variable "egress_subnet_cidr" {
  description = "CIDR block for the egress subnet"
  type        = string
}

variable "ekswork_subnet_cidrs" {
  description = "List of CIDR blocks for EKS worker subnets"
  type        = list(string)
}

variable "ekspods_subnet_cidrs" {
  description = "List of CIDR blocks for EKS pods subnets"
  type        = list(string)
}