output "lbc_role_arn" {
    value = aws_iam_role.lbc.arn
    description = "Used in helm install --set serviceAccount.annotations"
}

output "ebs_csi_role_arn" {
    value = aws_iam_role.ebs_csi.arn
  
}