output "alb_sg_id" {
  value       = aws_security_group.alb.id
  description = "value of the alb security group id"

}

output "rds_sg_id" {
  value       = aws_security_group.rds.id
  description = "value of the rds security group id"

}

output "eks_cluster_sg_id" {
  value = aws_security_group.eks_cluster_sg.id

}

output "eks_nodes_sg_id" {
  value = aws_security_group.eks_nodes_sg.id

}