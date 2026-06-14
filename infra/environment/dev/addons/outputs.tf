output "lbc_role_arn" {
    value = module.eks_addons.lbc_role_arn
    description = "Used in helm install for the Load Balancer Controller" 
}

output "ebs_csi_role_arn" {
    value = module.eks_addons.ebs_csi_role_arn
    
}