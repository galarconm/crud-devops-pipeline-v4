variable "project_name" {
  description = "The name of the project for tagging purposes"
  type        = string

}

variable "environment" {
  description = "The environment for tagging purposes (e.g., dev, staging, prod)"
  type        = string

  default = "dev"
}

variable "subnets_ids" {
  description = "Private subnet IDs for the RDS instance placement"
  type        = list(string)

}

variable "security_group_id" {
  type        = string
  description = "The security group ID to associate with the RDS instance"

}

variable "db_username" {
  description = "The username for the RDS database"
  type        = string

}

variable "db_password" {
  description = "The password for the RDS database"
  type        = string
  sensitive   = true

}

variable "db_name" {
  description = "The name of the RDS database"
  type        = string
  default     = "cruddb"

}

variable "instance_class" {
  description = "The instance class for the RDS database"
  type        = string
  default     = "db.t3.micro"

}

variable "allocated_storage" {
  description = "The allocated storage (in GB) for the RDS database"
  type        = number
  default     = 20

}