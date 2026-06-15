output "endpoint" {
  value       = aws_db_instance.main.address
  description = "The endpoint of the RDS instance"

}

output "db_name" {
  value       = aws_db_instance.main.db_name
  description = "The name of the RDS database"

}