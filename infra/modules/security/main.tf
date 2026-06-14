locals {
  name = "${var.project_name}-${var.environment}"

}

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"

  }

}

resource "aws_security_group" "rds" {
    name        = "${local.name}-rds-sg"
    description = "Security group for RDS Instances"
    vpc_id = var.vpc_id

   

    ingress {
        description = "Allow traffic from Bastion for DB management"
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        security_groups = [ aws_security_group.eks_nodes_sg.id]

    }

    tags = {
      Name = "${local.name}-rds-sg"
    }

}

resource "aws_security_group" "eks_cluster_sg" {
  name = "${local.name}-eks-cluster-sg"
  description = "Security group for EKS control plane"
  vpc_id = var.vpc_id
  tags = { Name = "${local.name}-eks-cluster-sg" }

}

resource "aws_security_group" "eks_nodes_sg" {
  name = "${local.name}-eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id = var.vpc_id
  tags = { Name = "${local.name}-eks-nodes-sg" }
  
}

resource "aws_security_group_rule" "cluster_ingress_nodes_443" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  security_group_id = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  description = "Allow EKS worker nodes to communicate with control plane on port 443"
  
}

resource "aws_security_group_rule" "cluster_egress_nodes_kubelet" {
  type        = "egress"
  from_port   = 10250
  to_port     = 65535
  protocol    = "tcp"
  security_group_id = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  description = "Allow EKS control plane to communicate with worker nodes on kubelet port"
  
}

resource "aws_security_group_rule" "cluster_egress_nodes_443" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
  description              = "Control plane to node webhooks"
}

resource "aws_security_group_rule" "nodes_ingress_cluster_kubelet" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = aws_security_group.eks_cluster_sg.id
  description              = "Control plane to nodes kubelet"
}

resource "aws_security_group_rule" "nodes_ingress_cluster_443" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = aws_security_group.eks_cluster_sg.id
  description              = "Control plane webhooks to nodes"
}

resource "aws_security_group_rule" "nodes_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "Node to node communication VPC CNI"
}

resource "aws_security_group_rule" "nodes_ingress_alb" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = aws_security_group.alb.id
  description              = "ALB to backend pods"
}

resource "aws_security_group_rule" "nodes_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_nodes_sg.id
  description       = "Allow all outbound ECR Secrets Manager STS"
}