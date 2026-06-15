variable "oidc_provider_arn" {
  type        = string
  description = "The ARN of the OIDC provider for the EKS cluster."

}

variable "oidc_provider_url" {
  type        = string
  description = "The URL of the OIDC provider for the EKS cluster."
}

variable "secret_arn" {
  type = string

}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

