provider "aws" {
  region = "us-west-1"
}

# uc davis networks
# ["169.237.0.0/16", "128.120.0.0/16", "152.79.0.0/16"]

# AWS Client VPN Endpoint
# resource "aws_ec2_client_vpn_endpoint" "this" {
#   description           = "Client VPN endpoint for Fargate Consul server access"
#   server_certificate_arn = var.server_certificate_arn
#   authentication_options {
#     type = "certificate-authentication"
#     root_certificate_chain_arn = var.server_certificate_arn
#   }
#   client_cidr_block     = var.vpn_cidr
#   split_tunnel          = true
#   vpc_id                = var.vpc_id
#
#   # Security group
#   security_group_ids = [aws_security_group.vpn_sg.id]
#
#   # Required connection log options block
#   connection_log_options {
#     enabled               = true
#     cloudwatch_log_group  = aws_cloudwatch_log_group.vpn_log_group.name
#     cloudwatch_log_stream = aws_cloudwatch_log_stream.vpn_log_stream.name
#   }
#
#   # Authentication and authorization settings go here
#   authentication_options {
#     type = "certificate-authentication"
#     root_certificate_chain_arn = var.server_certificate_arn
#   }
# }

# CloudWatch Log Group for VPN Logs
resource "aws_cloudwatch_log_group" "vpn_log_group" {
  name              = "/vpn"
  retention_in_days = 30  # Set as needed (e.g., 30 days)
}

# CloudWatch Log Stream for VPN Logs
resource "aws_cloudwatch_log_stream" "vpn_log_stream" {
  name           = "danswer-internal"
  log_group_name = aws_cloudwatch_log_group.vpn_log_group.name
}

# Security Group for VPN Endpoint
resource "aws_security_group" "vpn_sg" {
  name        = "vpn_sg"
  description = "Allow inbound traffic for Client VPN"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ "172.30.0.0/16"] # 10.0.100.0/24 ]
  }

  # Ingress rule allowing inbound traffic from VPN client range
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.1.0/24"]  # Cloud VPN range
  }
}

# Subnet Associations
# resource "aws_ec2_client_vpn_network_association" "this" {
#   for_each             = toset(var.subnet_ids)
#   client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
#   subnet_id              = each.value
# }
#
# # Authorization Rule to Allow Access to VPC Resources
# resource "aws_ec2_client_vpn_authorization_rule" "this" {
#   client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
#   target_network_cidr    = "172.30.0.0/16" # 10.0.100.0/24  # the on-premises network
#   authorize_all_groups   = true
# }

# Routes to Allow VPN Access to Private Resources
# resource "aws_ec2_client_vpn_route" "vpn_route" {
#   client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
#   destination_cidr_block = "10.0.0.0/16"  # The VPC CIDR block
#   target_vpc_subnet_id   = var.subnet_ids[0]
# }
