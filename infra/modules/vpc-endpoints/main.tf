locals {
  name                = "${var.project_name}-${var.environment}"
  interface_endpoints = ["ec2", "ecr.api", "ecr.dkr", "sts"]
}

resource "aws_security_group" "endpoints" {
  name        = "${local.name}-vpc-endpoints-sg"
  description = "Allow HTTPS from EKS nodes/control plane to VPC interface endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from EKS nodes and control plane"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-vpc-endpoints-sg" }
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(local.interface_endpoints)
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-east-1.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.middleware_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${local.name}-${each.value}-endpoint" }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.gateway_route_table_ids

  tags = { Name = "${local.name}-s3-endpoint" }
}