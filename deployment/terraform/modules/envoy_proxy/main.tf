terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_secretsmanager_secret_version" "consul_token" {
  secret_id = var.consul_token_secret_id
}

data "aws_secretsmanager_secret_version" "consul_ca_cert" {
  secret_id = var.consul_ca_cert_secret_id
}

data "aws_secretsmanager_secret_version" "consul_server_cert" {
  secret_id = var.consul_server_cert_secret_id
}

locals {
  consul_token = data.aws_secretsmanager_secret_version.consul_token.secret_string

  envoy_command = <<-EOF
# Update system and install dependencies
yum update -y && yum install -y wget unzip

# Install Consul
wget -O /tmp/consul.zip "https://releases.hashicorp.com/consul/${var.consul_version}/consul_${var.consul_version}_linux_amd64.zip"
unzip /tmp/consul.zip -d /usr/local/bin/
chmod +x /usr/local/bin/consul
rm /tmp/consul.zip

# Set environment variables
export CONSUL_HTTP_TOKEN="${local.consul_token}"

# Reload Consul configuration
consul reload

# Start Envoy sidecar proxy using Docker
SERVICE_NAME="your-service-name"  # Replace with your actual service name
consul connect envoy \
    -token=${local.consul_token} \
    -sidecar-for ${var.service_name} \
    -envoy-image envoyproxy/envoy:v1.26.4 \
    > /tmp/sidecar-proxy.log 2>&1 &
EOF


}

# https://developer.hashicorp.com/consul/docs/connect/proxies/envoy

resource "aws_ecs_task_definition" "envoy" {
  execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecsTaskExecutionRole"
  task_role_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecsTaskRole"
  family = "envoy"
  container_definitions = jsonencode([
    {
      name      = "envoy"
      image     = "envoyproxy/envoy:v1.18.3"
      cpu       = 256
      memory    = 512
      essential = true

      portMappings = [
        {
          containerPort = 19000
          hostPort      = 19000
          protocol      = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "envoy-config"
          containerPath = "/etc/envoy"
        }
      ]
      environment = [
        {
          name  = "CONSUL_HTTP_ADDR"
          value = "http://${var.consul_server_ip}:${var.tls_enabled ? 8501 : 8500}"
        },
        {
          name  = "CONSUL_HTTP_SSL"
          value = var.tls_enabled
        }
      ]
      secrets = [
        {
          name      = "CONSUL_TOKEN"
          valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:${var.consul_token_secret_id}"
        },
        {
          name      = "CONSUL_CACERT"
          valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:${var.consul_ca_cert_secret_id}"
        },
        # {
        #   name      = "CONSUL_CLIENT_CERT"
        #   valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:${var.consul_client_cert_secret_id}"
        # },
        {
          name      = "CONSUL_CLIENT_KEY"
          valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:${var.consul_client_key_secret_id}"
        }
      ]
    }
  ])
  volume {
    name = "envoy-config"
    host_path = "/path/to/your/envoy/config"
  }
}

data "aws_region" "current" {}
