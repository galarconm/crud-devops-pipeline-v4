output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.crud_devops_pipeline_vpc.id
}

output "frontend_subnet_ids" {
  description = "List of frontend web subnet IDs"
  value       = aws_subnet.frontend_web[*].id
}

output "middleware_subnet_ids" {
  description = "List of middleware subnet IDs"
  value       = aws_subnet.middleware[*].id
}

output "data_subnet_ids" {
  description = "List of data subnet IDs"
  value       = aws_subnet.data[*].id
}

output "transit_gateway_subnet_ids" {
  description = "List of transit gateway attachment subnet IDs"
  value       = aws_subnet.transit_gateway[*].id
}

output "egress_subnet_id" {
  description = "List of egress (public NAT) subnet IDs"
  value       = aws_subnet.egress.id
}

output "ekswork_subnet_ids" {
  description = "List of EKS node subnet IDs"
  value       = aws_subnet.ekswork[*].id
}

output "ekspods_subnet_ids" {
  description = "List of EKS pod subnet IDs (secondary CIDR)"
  value       = aws_subnet.ekspods[*].id
}

output "front_route_table_id" {
  description = "Route table ID for frontend web subnets"
  value       = aws_route_table.front.id
}

output "middleware_route_table_id" {
  description = "Route table ID for middleware subnets"
  value       = aws_route_table.middleware.id
}

output "data_route_table_id" {
  description = "Route table ID for data subnets"
  value       = aws_route_table.data.id
}

output "eks_route_table_ids" {
  description = "Route table IDs for ekswork/ekspods (one per AZ)"
  value       = aws_route_table.eks[*].id
}
