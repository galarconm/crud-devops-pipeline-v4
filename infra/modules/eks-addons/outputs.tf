output "lbc_role_arn" {
  value       = aws_iam_role.lbc.arn
  description = "Used in helm install --set serviceAccount.annotations"
}

output "ebs_csi_role_arn" {
  value = aws_iam_role.ebs_csi.arn

}

output "external_dns_role_arn" {
  value = aws_iam_role.external_dns.arn
}

output "external_dns_zone_id" {
  value = aws_route53_zone.internal.zone_id
}

output "external_dns_zone_name" {
  value = aws_route53_zone.internal.name
}

output "alb_logs_bucket" {
  value = aws_s3_bucket.alb_logs.id
}
