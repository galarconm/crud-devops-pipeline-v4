output "file_system_id" {
  value = aws_efs_file_system.main.id
}

output "application_data_access_point_id" {
  value = aws_efs_access_point.application_data.id
}

output "application_logs_access_point_id" {
  value = aws_efs_access_point.application_logs.id
}
