variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "middleware_subnet_ids" {
  description = "Subnets where the interface endpoint ENIs live"
  type        = list(string)
}

variable "gateway_route_table_ids" {
  description = "Route tables that need the S3 gateway endpoint associated"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to reach the endpoints over 443"
  type        = list(string)
}