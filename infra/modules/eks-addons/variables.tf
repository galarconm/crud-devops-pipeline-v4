variable "project_name" {
  type        = string
  description = "The name of the project."

}

variable "environment" {
  type = string
}

variable "oidc_provider_url" {
  type = string

}

variable "oidc_provider_arn" {
  type = string
}

variable "cluster_name" {
  type = string
  
}