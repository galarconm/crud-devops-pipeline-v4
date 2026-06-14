variable "project_name" {
  type        = string
  description = "The name of the project. This will be used as a prefix for all resources created by this module."
}

variable "environment" {
  type        = string
  description = "The environment for which to create resources."
}


variable "backend_instance_id" {
  type        = string
  description = "The ID of the backend instance."
}

variable "db_instance_id" {
  type        = string
  description = "The ID of the database instance."
}

variable "alb_arn_suffix" {
  type        = string
  description = "The suffix for the Application Load Balancer ARN."
}

variable "alert_email" {
  type        = string
  description = "The email address to which alerts should be sent."
}