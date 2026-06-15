locals {
  oidc_url = replace(var.oidc_provider_url, "https://", "")
  name     = "${var.project_name}-${var.environment}"
}

resource "aws_iam_role" "backend_irsa" {
  name = "${local.name}-backend-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${local.oidc_url}:sub" = "system:serviceaccount:${var.environment}-crud-backend"
          "${local.oidc_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

}

resource "aws_iam_role_policy" "backend_secrets" {
  name = "read-db-secret"
  role = aws_iam_role.backend_irsa.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = var.secret_arn
    }]
  })
}

