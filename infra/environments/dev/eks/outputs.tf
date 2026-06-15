output "cluster_name" {
  value = module.eks.cluster_name

}

output "backend_irsa_role_arn" {
  value       = module.iam.backend_irsa_role_arn
  description = "Paste this value into k8s/base/serviceaccount.yaml"
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint

}

output "cluster_certificate_authority" {
  value = module.eks.cluster_certificate_authority

}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn

}

output "oidc_provider_url" {
  value = module.eks.oidc_provider_url

}

