
output "vpc_id" {
    value = module.networking.vpc_id
  
}

output "public_subnet_ids" {
    value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
    value = module.networking.private_subnet_ids
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

