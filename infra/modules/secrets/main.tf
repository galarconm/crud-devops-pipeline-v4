resource "aws_secretsmanager_secret" "db" {

  name                    = "${var.project_name}/${var.environment}/db-secret"
  recovery_window_in_days = 0 # 0 means the secrete can be deleted immediately.connection {
  tags = {
    Name = "${var.project_name}-${var.environment}-db-secret"
  }

}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.db_host
    name     = var.db_name
    port     = 5432
    dbname   = var.db_name
  })

}

resource "aws_secretsmanager_secret" "dev_db" {
  name                    = "${var.project_name}/${var.environment}/database"
  description             = "Development RDS PostgreSQL credentials"
  recovery_window_in_days = 0 # 0 means the secret can be deleted immediately

}

resource "aws_secretsmanager_secret_version" "dev_db" {
  secret_id = aws_secretsmanager_secret.dev_db.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.db_host
    name     = var.db_name
    port     = 5432
    dbname   = var.db_name
    url      = "postgresql://${var.db_username}:${var.db_password}@${var.db_host}:5432/${var.db_name}"
  })
}

# resource "aws_secretsmanager_secret" "staging_db" {
#   name = "${var.project_name}/${var.environment}/database"
#   description = "Staging RDS PostgreSQL credentials"
#   recovery_window_in_days = 0 # 0 means the secret can be deleted immediately

#   tags ={
#     Environment = "staging"
#     ManagedBy = "Terraform"
#   }

# }

# resource "aws_secretsmanager_secret_version" "name" {
#   secret_id = aws_secretsmanager_secret.staging_db.id
#   secret_string = jsonencode({
#     username = var.staging_db_username
#     password = var.staging_db_password
#     host     = var.staging_db_host
#     name     = var.staging_db_name
#     port     = 5432
#     dbname   = var.staging_db_name
#     url      = "postgresql://${var.staging_db_username}:${var.staging_db_password}@${var.staging_db_host}:5432/${var.staging_db_name}"

#   })

# }


# resource "aws_secretsmanager_secret" "prod_db" {
#   name = "${var.project_name}/${var.environment}/database"
#   description = "Production RDS PostgreSQL credentials"
#   recovery_window_in_days = 30 # 30 days recovery window for production secrets
#   tags ={
#     Environment = "prod"
#     ManagedBy = "Terraform"
#   }

# }
