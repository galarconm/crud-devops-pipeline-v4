variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "data_subnet_ids" {
  description = "Data-layer subnet IDs (one per AZ) for the EFS mount targets"
  type        = list(string)
}

variable "eks_nodes_sg_id" {
  description = "Security group of the EKS nodes, allowed to mount the EFS over NFS"
  type        = string
}
