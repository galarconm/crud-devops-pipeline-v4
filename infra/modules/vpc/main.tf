locals {
  project_name = "${var.project_name}-${var.environment}"
}

# VPC
resource "aws_vpc" "crud_devops_pipeline_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name        = "${local.project_name}-vpc"
    Environment = var.environment
  }

}

resource "aws_vpc_ipv4_cidr_block_association" "crud_devops_pipeline_vpc_ipv4" {
  vpc_id     = aws_vpc.crud_devops_pipeline_vpc.id
  cidr_block = var.vpc_ipv4_cidr_block
}


# Internet Gateway
resource "aws_internet_gateway" "crud_devops_pipeline_igw" {
  vpc_id = aws_vpc.crud_devops_pipeline_vpc.id

  tags = {
    Name        = "${local.project_name}-igw"
    Environment = var.environment
  }
}
# 1 frontend web
resource "aws_subnet" "frontend_web" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.crud_devops_pipeline_vpc.id
  cidr_block              = var.frontend_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name        = "${local.project_name}-frontend-web-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# 2 middleware subnet
resource "aws_subnet" "middleware" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.crud_devops_pipeline_vpc.id
  cidr_block              = var.middleware_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name                                        = "${local.project_name}-middleware-subnet-${count.index + 1}"
    Environment                                 = var.environment
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# 3 data subnet
resource "aws_subnet" "data" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.crud_devops_pipeline_vpc.id
  cidr_block              = var.data_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name        = "${local.project_name}-data-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# 4 transit gateway subnet
resource "aws_subnet" "transit_gateway" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.crud_devops_pipeline_vpc.id
  cidr_block              = var.transit_gateway_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name        = "${local.project_name}-transit-gateway-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# 5 egress public subnet
resource "aws_subnet" "egress" {
  vpc_id                  = aws_vpc.crud_devops_pipeline_vpc.id
  cidr_block              = var.egress_subnet_cidr
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true
  tags = {
    Name        = "${local.project_name}-egress-subnet-1"
    Environment = var.environment
  }
}

# 6 ekswork subnet
resource "aws_subnet" "ekswork" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.crud_devops_pipeline_vpc.id
  cidr_block              = var.ekswork_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name                                        = "${local.project_name}-ekswork-subnet-${count.index + 1}"
    Environment                                 = var.environment
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# 7 ekspods subnet
resource "aws_subnet" "ekspods" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.crud_devops_pipeline_vpc.id
  cidr_block              = var.ekspods_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  depends_on              = [aws_vpc_ipv4_cidr_block_association.crud_devops_pipeline_vpc_ipv4]
  map_public_ip_on_launch = false
  tags = {
    Name                                        = "${local.project_name}-ekspods-subnet-${count.index + 1}"
    Environment                                 = var.environment
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
# Nat Gateway Privado
resource "aws_nat_gateway" "private" {
  count             = length(var.availability_zones)
  connectivity_type = "private"
  subnet_id         = aws_subnet.middleware[count.index].id

  tags = {
    Name        = "${local.project_name}-private-nat-gateway-${count.index + 1}"
    Environment = var.environment
  }
}

# EIP 
resource "aws_eip" "nat_public" {
  vpc        = true
  depends_on = [aws_internet_gateway.crud_devops_pipeline_igw]
  tags = {
    Name        = "${local.project_name}-public-nat-eip"
    Environment = var.environment
  }
}

# NAT Gateway Público
resource "aws_nat_gateway" "public" {
  allocation_id = aws_eip.nat_public.id
  subnet_id     = aws_subnet.egress.id
  depends_on    = [aws_internet_gateway.crud_devops_pipeline_igw]
  tags = {
    Name        = "${local.project_name}-public-nat-gateway"
    Environment = var.environment
  }

}

# route tables
# RT for frontend, middleware, data
resource "aws_route_table" "front" {
  vpc_id = aws_vpc.crud_devops_pipeline_vpc.id
  tags = {
    Name        = "${local.project_name}-frontend-route-table"
    Environment = var.environment
  }
}

resource "aws_route" "front_default" {
  route_table_id         = aws_route_table.front.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.public.id
}

resource "aws_route_table" "middleware" {
  vpc_id = aws_vpc.crud_devops_pipeline_vpc.id
  tags = {
    Name        = "${local.project_name}-middleware-route-table"
    Environment = var.environment
  }
}

resource "aws_route" "middleware_default" {
  route_table_id         = aws_route_table.middleware.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.public.id
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.crud_devops_pipeline_vpc.id
  tags = {
    Name        = "${local.project_name}-data-route-table"
    Environment = var.environment
  }
}

resource "aws_route" "data_default" {
  route_table_id         = aws_route_table.data.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.public.id
}


resource "aws_route_table_association" "frontend_web" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.frontend_web[count.index].id
  route_table_id = aws_route_table.front.id
}

resource "aws_route_table_association" "middleware" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.middleware[count.index].id
  route_table_id = aws_route_table.middleware.id
}

resource "aws_route_table_association" "data" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

resource "aws_route_table" "eks" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.crud_devops_pipeline_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.private[count.index].id
  }
  tags = {
    Name        = "${local.project_name}-eks-route-table-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "ekswork" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.ekswork[count.index].id
  route_table_id = aws_route_table.eks[count.index].id
}

resource "aws_route_table_association" "ekspods" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.ekspods[count.index].id
  route_table_id = aws_route_table.eks[count.index].id

}

resource "aws_route_table" "egress" {
  vpc_id = aws_vpc.crud_devops_pipeline_vpc.id

  tags = {
    Name        = "${local.project_name}-egress-route-table"
    Environment = var.environment
  }
}

resource "aws_route" "egress_default" {
  route_table_id         = aws_route_table.egress.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id              = aws_internet_gateway.crud_devops_pipeline_igw.id
}

resource "aws_route_table_association" "egress" {
  subnet_id      = aws_subnet.egress.id
  route_table_id = aws_route_table.egress.id
}
