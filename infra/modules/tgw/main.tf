locals {
  project_name = "${var.project_name}-${var.environment}"
}

resource "aws_ec2_transit_gateway" "main" {
  description                     = "${local.project_name}-tgw"
  amazon_side_asn                 = 64512
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  auto_accept_shared_attachments  = "disable"

  tags = {
    Name        = "${local.project_name}-tgw"
    Environment = var.environment
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = var.vpc_id
  subnet_ids         = var.tgwattch_subnet_ids

  tags = {
    Name        = "${local.project_name}-tgw-attachment"
    Environment = var.environment
  }
}

resource "aws_route" "front_tgw" {
  route_table_id         = var.front_route_table_id
  destination_cidr_block = var.tgw_destination_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.main]
}

resource "aws_route" "middleware_tgw" {
  route_table_id         = var.middleware_route_table_id
  destination_cidr_block = var.tgw_destination_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.main]
}

resource "aws_route" "data_tgw" {
  route_table_id         = var.data_route_table_id
  destination_cidr_block = var.tgw_destination_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.main]
}