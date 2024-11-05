# Based on:  https://github.com/hashicorp/terraform-aws-consul-ecs/blob/main/modules/dev-server/main.tf

resource "tls_private_key" "ca" {
  count       = local.generate_ca ? 1 : 0
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "ca" {
  count           = local.generate_ca ? 1 : 0
  private_key_pem = tls_private_key.ca[count.index].private_key_pem

  subject {
    common_name  = "Consul Agent CA"
    organization = "Edumore"
  }

  // 2.5 years.
  validity_period_hours = 21900

  is_ca_certificate  = true
  set_subject_key_id = true

  allowed_uses = [
    "digital_signature",
    "cert_signing",
    "crl_signing",
  ]
}

resource "aws_secretsmanager_secret" "ca_key" {
  count                   = local.generate_ca ? 1 : 0
  name                    = "${var.name}-ca-key"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "ca_key" {
  count         = local.generate_ca ? 1 : 0
  secret_id     = aws_secretsmanager_secret.ca_key[count.index].id
  secret_string = tls_private_key.ca[count.index].private_key_pem
}

resource "aws_secretsmanager_secret" "ca_cert" {
  count                   = local.generate_ca ? 1 : 0
  name                    = "${var.name}-ca-cert"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "ca_cert" {
  count         = local.generate_ca ? 1 : 0
  secret_id     = aws_secretsmanager_secret.ca_cert[count.index].id
  secret_string = tls_self_signed_cert.ca[count.index].cert_pem
}

locals {
  // We use this command to generate the server certs dynamically before the servers start
  // because we need to add the IP of the task as a SAN to the certificate, and we don't know that
  // IP ahead of time.
  consul_server_tls_init_command = <<EOF
ECS_IPV4=$(curl -s $ECS_CONTAINER_METADATA_URI_V4 | jq -r '.Networks[0].IPv4Addresses[0]')
cd /consul
echo "$CONSUL_CACERT_PEM" > ./consul-agent-ca.pem
echo "$CONSUL_CAKEY" > ./consul-agent-ca-key.pem
consul tls cert create -server \
  -node="${local.node_name}" \
  -dc="${var.datacenter}" \
  -additional-ipaddress=$ECS_IPV4 \
  -additional-dnsname="${var.name}.${local.service_discovery_namespace}" \
%{if length(var.additional_dns_names) > 0~}
  %{for dnsname in var.additional_dns_names~}
    -additional-dnsname="${dnsname}" \
  %{endfor~}
%{endif~}
EOF

  tls_init_container = {
    name             = "tls-init"
    image            = var.consul_image
    essential        = false
    log_configuration = {
      log_driver = "awslogs"

      options = {
        awslogs-group         = "/ecs/hybrid-cluster"
        awslogs-region        = data.aws_region.current.id
        awslogs-stream-prefix = "ecs"
      }
    }

    mountPoints = [
      {
        sourceVolume  = "consul-data"
        containerPath = "/consul"
      }
    ]
    entryPoint = ["/bin/sh", "-ec"]
    command    = [replace(local.consul_server_tls_init_command, "\r", "")]
    secrets = var.tls ? [
      {
        name      = "CONSUL_CACERT_PEM",
        valueFrom = local.ca_cert_arn
      },
      {
        name      = "CONSUL_CAKEY",
        valueFrom = local.ca_key_arn
      }
    ] : []
  }
  tls_init_containers = var.tls ? [local.tls_init_container] : []
}

