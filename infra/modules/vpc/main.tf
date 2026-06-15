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
# Internet Gateway
resource "aws_internet_gateway" "crud_devops_pipeline_igw" {
  vpc_id = aws_vpc.crud_devops_pipeline_vpc.id

  tags = {
    Name        = "${local.project_name}-igw"
    Environment = var.environment
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.crud_devops_pipeline_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name                                        = "${local.project_name}-public-subnet-${count.index + 1}"
    Environment                                 = var.environment
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Private Subnet
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.crud_devops_pipeline_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                        = "${local.project_name}-private-subnet-${count.index + 1}"
    Environment                                 = var.environment
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# NAT Gateway in first public subnet
resource "aws_eip" "elastic-ip" {
  depends_on = [aws_internet_gateway.crud_devops_pipeline_igw]
  tags = {
    Name        = "${local.project_name}-nat-eip"
    Environment = var.environment
  }

}
resource "aws_nat_gateway" "crud_devops_pipeline_nat" {
  allocation_id = aws_eip.elastic-ip.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.crud_devops_pipeline_igw]

  tags = {
    Name        = "${local.project_name}-nat-gateway"
    Environment = var.environment
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.crud_devops_pipeline_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.crud_devops_pipeline_igw.id
  }
  tags = {
    Name        = "${local.project_name}-public-rt"
    Environment = var.environment
  }
}
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table for Private Subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.crud_devops_pipeline_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.crud_devops_pipeline_nat.id
  }
  tags = {
    Name        = "${local.project_name}-private-rt"
    Environment = var.environment
  }
}
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

