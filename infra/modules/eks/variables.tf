variable "project_name" {
  description = "The name of the project."
  type        = string

}

variable "environment" {
  description = "The environment (e.g., dev, staging, prod)."
  type        = string

}

variable "vpc_id" {
  description = "The ID of the VPC where the EKS cluster will be deployed."
  type        = string

}

variable "middleware_subnet_ids" {
  description = "donde EKS crea las ENIs del control plane"
  type        = list(string)

}

variable "ekswork_subnet_ids" {
  description = "The IDs of the subnets for the EKS worker nodes."
  type        = list(string)

}

variable "cluster_version" {
  description = "The version of Kubernetes to use for the EKS cluster."
  type        = string
  default     = "1.35"

}

variable "node_instance_type" {
  description = "The instance type for the EKS worker nodes."
  type        = string
  default     = "t3.medium"
}

variable "node_min_size" {
  type        = number
  default     = 1
  description = "The minimum number of worker nodes in the EKS cluster."
}

variable "node_max_size" {
  type        = number
  default     = 3
  description = "The maximum number of worker nodes in the EKS cluster."
}

variable "node_desired_size" {
  type        = number
  default     = 2
  description = "The desired number of worker nodes in the EKS cluster."

}

variable "cluster_sg_id" {
  type        = string
  description = "The ID of the security group for the EKS cluster control plane."

}

variable "node_sg_id" {
  type        = string
  description = "The ID of the security group for EKS worker nodes."
}