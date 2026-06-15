output "cluster_name" {
  value       = aws_eks_cluster.main.name
  description = "The name of the EKS cluster."

}

output "cluster_endpoint" {
  value       = aws_eks_cluster.main.endpoint
  description = "The endpoint of the EKS cluster."

}

output "cluster_certificate_authority" {
  value       = aws_eks_cluster.main.certificate_authority[0].data
  description = "The certificate authority data for the EKS cluster."

}

output "oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.cluster.arn
  description = "The ARN of the OIDC provider for the EKS cluster."

}

output "oidc_provider_url" {
  value       = aws_iam_openid_connect_provider.cluster.url
  description = "The URL of the OIDC provider for the EKS cluster."

}

