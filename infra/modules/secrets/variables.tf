variable "project_name" {
  description = "The name of the project to which the secrets belong."
  type        = string

}

variable "environment" {
  description = "The environment (e.g., dev, staging, prod) for which the secrets are being created."
  type        = string

}

variable "db_username" {
  description = "The username for the database."
  type        = string
}

variable "db_password" {
  description = "The password for the database."
  type        = string
  sensitive   = true
}

variable "db_host" {
  description = "The host address of the database."
  type        = string

}

variable "db_name" {
  description = "The name of the database."
  type        = string

}

# variable "staging_db_username" {
#     description = "The username for the staging database."
#     type        = string
# }

# variable "staging_db_password" {
#     description = "The password for the staging database."
#     type        = string
#     sensitive = true
# }

# variable "staging_db_host" {
#     description = "The host address of the staging database."
#     type        = string

# }

# variable "staging_db_name" {
#     description = "The name of the staging database."
#     type        = string
# }

