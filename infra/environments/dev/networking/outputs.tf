
output "vpc_id" {
  value = module.networking.vpc_id

}

output "frontend_subnet_ids" {
  value = module.networking.frontend_subnet_ids
}

output "middleware_subnet_ids" {
  value = module.networking.middleware_subnet_ids
}

output "data_subnet_ids" {
  value = module.networking.data_subnet_ids
}

output "transit_gateway_subnet_ids" {
  value = module.networking.transit_gateway_subnet_ids
}

output "egress_subnet_id" {
  value = module.networking.egress_subnet_id
}

output "ekswork_subnet_ids" {
  value = module.networking.ekswork_subnet_ids
}

output "ekspods_subnet_ids" {
  value = module.networking.ekspods_subnet_ids
}

output "alb_sg_id" {
  value = module.sg.alb_sg_id
}

output "rds_sg_id" {
  value = module.sg.rds_sg_id

}

output "eks_cluster_sg_id" {
  value = module.sg.eks_cluster_sg_id
}

output "eks_nodes_sg_id" {
  value = module.sg.eks_nodes_sg_id

}

output "front_route_table_id" {
  description = "Route table ID for frontend web subnets"
  value       = module.networking.front_route_table_id
}

output "middleware_route_table_id" {
  description = "Route table ID for middleware subnets"
  value       = module.networking.middleware_route_table_id
}

output "data_route_table_id" {
  description = "Route table ID for data subnets"
  value       = module.networking.data_route_table_id
}

output "eks_route_table_ids" {
  description = "Route table IDs for ekswork/ekspods (one per AZ)"
  value       = module.networking.eks_route_table_ids
}