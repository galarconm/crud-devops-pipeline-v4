output "backend_irsa_role_arn" {
  value       = aws_iam_role.backend_irsa.arn
  description = "The ARN of the IAM role for IRSA used by the backend service."

}