
resource "nomad_job" "consul_server" {
  jobspec = templatefile("${path.module}/consul_server.hcl", {
    datacenter    = var.datacenter
    consul_version = var.consul_version
  })
}

# Load the Consul agent HCL file
resource "nomad_job" "consul_client" {
  jobspec = templatefile("${path.module}/consul_agent.hcl", {
    datacenter    = var.datacenter
    consul_version = var.consul_version
  })
}

resource "aws_security_group" "consul" {
  name        = "consul-sg"
  description = "Security group for Consul communication among nodes"
  vpc_id      = var.vpc_id
}

### Ingress Rules for TCP Ports

/*
This rule allows inbound TCP communication for the following ports:
- 8300: Consul server RPC communication (used for internal server-to-server communication)
- 8301: Serf LAN gossip (used for intra-datacenter node-to-node communication)
- 8302: Serf WAN gossip (used for inter-datacenter server-to-server communication)
- 8500: Consul HTTP API (used for querying and interacting with the Consul API)
- 8600: Consul DNS interface (used for service discovery via DNS queries)
*/

locals {
  tcp_ports = {
    "consul_rpc"    = 8300
    "serf_lan_tcp"  = 8301
    "serf_wan_tcp"  = 8302
    "http_api"      = 8500
    "dns_tcp"       = 8600
  }
}

resource "aws_security_group_rule" "tcp_ingress" {
  for_each = local.tcp_ports
  type              = "ingress"
  from_port         = each.value
  to_port           = each.value
  protocol          = "tcp"
  security_group_id = aws_security_group.consul.id
  cidr_blocks       = ["10.0.0.0/16"] # Replace with your VPC CIDR or specific IP range
  description       = "Allow TCP communication on port ${each.value} for ${each.key}"
}

### Ingress Rules for UDP Ports

/*
This rule allows inbound UDP communication for the following ports:
- 8301: Serf LAN gossip (UDP version of node-to-node communication)
- 8302: Serf WAN gossip (UDP version of inter-datacenter server-to-server communication)
- 8600: Consul DNS interface (UDP version of service discovery via DNS queries)
*/

locals {
  udp_ports = {
    "serf_lan_udp"  = 8301
    "serf_wan_udp"  = 8302
    "dns_udp"       = 8600
  }
}

resource "aws_security_group_rule" "udp_ingress" {
  for_each = local.udp_ports
  type              = "ingress"
  from_port         = each.value
  to_port           = each.value
  protocol          = "udp"
  security_group_id = aws_security_group.consul.id
  cidr_blocks       = ["10.0.0.0/16"] # Replace with your VPC CIDR or specific IP range
  description       = "Allow UDP communication on port ${each.value} for ${each.key}"
}

### Egress Rule

/*
This rule allows all outbound traffic from Consul nodes to the internet.
It is essential for Consul agents or servers to communicate with external services as required.
*/

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # All protocols
  security_group_id = aws_security_group.consul.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from Consul nodes"
}
