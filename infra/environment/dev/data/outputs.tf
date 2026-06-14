output "rds_endpoint" {
    value = module.rds.endpoint
    description = "The endpoint of the RDS instance"
  
}

output "db_name" {
    value = module.rds.db_name
    description = "The name of the RDS database"
  
}

output "secret_arn" {
    value = module.secrets.secret_arn
    description = "The ARN of the secret"
  
}

output "secret_name" {
    value = module.secrets.secret_name
    description = "The name of the secret"
}   