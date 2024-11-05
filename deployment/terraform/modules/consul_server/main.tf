data aws_region "current" {}
data aws_caller_identity "current" {}

# https://github.com/hashicorp/terraform-aws-consul-ecs/blob/main/modules/dev-server/main.tf
# https://github.com/hashicorp/terraform-aws-consul-ecs/tree/v0.8.1

locals {

  // Determine which secrets are provided and which ones need to be created.
  generate_ca              = var.tls && var.generate_ca
  generate_bootstrap_token = var.acls && var.generate_bootstrap_token

  ca_cert_arn         = local.generate_ca ? aws_secretsmanager_secret.ca_cert[0].arn : var.ca_cert_arn
  ca_key_arn          = local.generate_ca ? aws_secretsmanager_secret.ca_key[0].arn : var.ca_key_arn
  bootstrap_token_arn = local.generate_bootstrap_token ? aws_secretsmanager_secret.bootstrap_token[0].arn : var.bootstrap_token_arn
  bootstrap_token     = var.bootstrap_token != "" ? var.bootstrap_token : random_uuid.bootstrap_token.result

  load_balancer = var.lb_enabled ? [{
    target_group_arn = aws_lb_target_group.this[0].arn
    container_name   = "consul"
    container_port   = 8500
  }] : []

  // Setup Consul server options
  consul_enterprise_enabled          = false
  enable_mesh_gateway_wan_federation = var.enable_mesh_gateway_wan_federation || length(var.primary_gateways) > 0 ? true : false
  node_name                          = var.node_name != "" ? var.node_name : var.name

  // If the user has passed an explicit Cloud Map service discovery namespace then use it.
  // Otherwise set the namespace to match the datacenter for the Consul server.
  service_discovery_namespace = var.service_discovery_namespace != "" ? var.service_discovery_namespace : var.datacenter
}

locals {

  consul_config = templatefile("${path.module}/consul_config.hcl", {
    node_name                          = local.node_name
    datacenter                         = var.datacenter
    tls                                = var.tls
    is_consul_1_14_plus                = local.is_consul_1_14_plus
    acls                               = var.acls
    bootstrap_token                    = local.bootstrap_token
    replication_token                  = var.replication_token
    primary_datacenter                 = var.primary_datacenter
    retry_join_wan                     = var.retry_join_wan
    primary_gateways                   = var.primary_gateways
    enable_mesh_gateway_wan_federation = local.enable_mesh_gateway_wan_federation
    enable_cluster_peering             = var.enable_cluster_peering
  })

  consul_server_command = <<EOF
echo "$CONSUL_CONFIG" > /consul/custom_config.hcl

echo $CONSUL_CONFIG

# Retrieve the public IP address
BIND_IP=$(curl -s "$ECS_CONTAINER_METADATA_URI_V4" | jq -r '.HostPublicIPv4Address // empty')
echo "public IP address is $BIND_IP"

# Fallback to private IP if public IP is not available
if [ -z "$BIND_IP" ]; then
  PRIVATE_IP=$(curl -s "$ECS_CONTAINER_METADATA_URI_V4" | jq -r '.Networks[0].IPv4Addresses[0]')
  echo "public IP is not available, using private IP address $PRIVATE_IP"
fi

BIND_IP=0.0.0.0

exec consul agent -server \
  -bootstrap \
  -ui \
  -advertise "$PRIVATE_IP" \
  -bind "$BIND_IP" \
  -client 0.0.0.0 \
  -data-dir /tmp/consul-data \
  -config-dir=/consul
EOF

  is_consul_1_14_plus = true
}


resource "aws_ecs_service" "consul" {
  name            = "consul"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.consul.arn
  desired_count   = var.cluster_size
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.subnets
    security_groups = [aws_security_group.consul.id]
    assign_public_ip = true
  }
  service_registries {
    registry_arn = aws_service_discovery_service.consul_service_discovery.arn
  }
  dynamic "load_balancer" {
    for_each = local.load_balancer
    content {
      target_group_arn = load_balancer.value["target_group_arn"]
      container_name   = load_balancer.value["container_name"]
      container_port   = load_balancer.value["container_port"]
    }
  }
  enable_execute_command = true
  wait_for_steady_state  = var.wait_for_steady_state

  depends_on = [
    aws_iam_role.ecs_task_execution
  ]
}

# Define the Cloud Map namespace
resource "aws_service_discovery_private_dns_namespace" "danswer_internal_namespace" {
  name        = var.service_discovery_namespace
  vpc         = var.vpc_id
  description = "Namespace for internal services"
}

# Define the Cloud Map service
resource "aws_service_discovery_service" "consul_service_discovery" {
  name = "consul"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.danswer_internal_namespace.id

    dns_records {
      type = "A"
      ttl  = 60
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "random_uuid" "bootstrap_token" {}

resource "aws_secretsmanager_secret" "bootstrap_token" {
  count = local.generate_bootstrap_token ? 1 : 0
  name  = "${var.name}-bootstrap-token"
}

resource "aws_secretsmanager_secret_version" "bootstrap_token" {
  count         = local.generate_bootstrap_token ? 1 : 0
  secret_id     = aws_secretsmanager_secret.bootstrap_token[count.index].id
  secret_string = local.bootstrap_token
}

resource "local_file" "consul_config" {
  content  = local.consul_config
  filename = "${path.module}/consul_config.out.hcl"
}

# Secret creation
resource "aws_secretsmanager_secret" "consul_config" {
  name = "consul_config"
}

resource "aws_secretsmanager_secret_version" "consul_config_version" {
  secret_id     = aws_secretsmanager_secret.consul_config.id
  secret_string = local.consul_config
}

resource "aws_ecs_task_definition" "consul" {
  family                   = "consul"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn = aws_iam_role.this_task.arn

  volume {
    name = "consul-data"
  }

  container_definitions = jsonencode(
    concat(
      local.tls_init_containers,
      [
        jsondecode(templatefile("${path.module}/consul_container_def.json", {
          consul_image = var.consul_image
          aws_region   = data.aws_region.current.name
          aws_acct_id  = data.aws_caller_identity.current.account_id
          consul_server_command = jsonencode([replace(local.consul_server_command, "\r", "")])
          depends_on = var.tls ? jsonencode([
            {
              containerName = "tls-init"
              condition     = "SUCCESS"
            },
          ]) : jsonencode([])
          secrets = var.tls ? jsonencode([
            {
              name      = "CONSUL_CACERT_PEM",
              valueFrom = local.ca_cert_arn
            },
            {
              name      = "CONSUL_CAKEY",
              valueFrom = local.ca_key_arn
            },
            {
              name = "CONSUL_CONFIG",
              valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:consul_config"
            }
          ]) : jsonencode([{
            name = "CONSUL_CONFIG",
            valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:consul_config"
          }])
        }))
      ]
    )
  )
}

resource "aws_security_group" "consul" {
  name        = "consul-sg"
  description = "Security group for Consul ECS service"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    self      = true
    security_groups = [var.bastion_host_sg_id]
  }

  # This is used for communication between Consul servers to maintain the cluster state (Raft protocol).
  ingress {
    from_port = 8300
    to_port   = 8300
    protocol  = "tcp"
    self      = true
  }

  # This is used for the DNS interface that allows services registered with Consul to be queried via DNS.
  ingress {
    from_port = 8600
    to_port   = 8600
    protocol  = "tcp"
    self      = true
    security_groups = [var.bastion_host_sg_id]
  }

  # This is used for HTTP access to the Consul API and the Web UI (if enabled).
  ingress {
    from_port = 8500
    to_port   = 8500
    protocol  = "tcp"
    self      = true
    security_groups = [var.bastion_host_sg_id]
  }

  ingress {
    from_port = 8501
    to_port   = 8501
    protocol  = "tcp"
    self      = true
    security_groups = [var.bastion_host_sg_id, var.ecs_service_sg_id]
  }

  ingress {
    from_port = 8502
    to_port   = 8502
    protocol  = "tcp"
    self      = true
    security_groups = [var.ecs_service_sg_id]
  }


  ingress {
    from_port = 8503
    to_port   = 8503
    protocol  = "tcp"
    self      = true
    security_groups = [var.ecs_service_sg_id]
  }

  # This is used for HTTP access to the Consul API and the Web UI (if enabled).
  ingress {
    from_port = 8500
    to_port   = 8500
    protocol  = "tcp"
    self      = true
    security_groups = [var.bastion_host_sg_id]
  }

  ingress {
    from_port = 8200
    to_port   = 8200
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.name}_execution"
  path = "/ecs/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution.id
  policy_arn = aws_iam_policy.this_execution.arn
}

resource "aws_iam_policy" "this_execution" {
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
%{if var.tls~}
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "${local.ca_cert_arn}",
        "${local.ca_key_arn}"
      ]
    },
%{endif~}
%{if var.acls~}
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "${local.bootstrap_token_arn}"
      ]
    },
%{endif~}
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# Attach the policy to the role
resource "aws_iam_role_policy" "ecs_task_execution_role_policy" {
  name = "ecs-task-execution-role-policy"
  role = aws_iam_role.ecs_task_execution.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Existing statements...

      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.consul_config.arn
      }
    ]
  })
}



resource "aws_iam_role" "this_task" {
  name = "${var.name}_task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "exec"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ssmmessages:CreateControlChannel",
            "ssmmessages:CreateDataChannel",
            "ssmmessages:OpenControlChannel",
            "ssmmessages:OpenDataChannel"
          ]
          Resource = "*"
        }
      ]
    })
  }
}

