locals {
  name = "${var.project_name}-${var.environment}"
}

resource "aws_efs_file_system" "main" {
  creation_token = "${local.name}-efs"
  encrypted      = true

  tags = {
    Name        = "${local.name}-efs"
    Environment = var.environment
  }
}

resource "aws_security_group" "efs" {
  name        = "${local.name}-efs-sg"
  description = "Security group for EFS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.eks_nodes_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name}-efs-sg"
    Environment = var.environment
  }
}

resource "aws_efs_mount_target" "main" {
  count = length(var.data_subnet_ids)

  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.data_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "application_data" {
  file_system_id = aws_efs_file_system.main.id

  root_directory {
    path = "/application-data"

    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name        = "${local.name}-efs-access-point"
    Environment = var.environment
  }
}

resource "aws_efs_access_point" "application_logs" {
  file_system_id = aws_efs_file_system.main.id

  root_directory {
    path = "/application-logs"

    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name        = "${local.name}-efs-access-point-logs"
    Environment = var.environment
  }

}