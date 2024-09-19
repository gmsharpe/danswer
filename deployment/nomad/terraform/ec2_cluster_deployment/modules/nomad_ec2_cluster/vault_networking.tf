### Ingress Rules for TCP Ports

/*
This rule allows inbound TCP communication for the following ports:
- 8200: Vault API communication (used for external interaction with Vault)
- 8201: Vault inter-node Raft communication (used for leader election and log replication in a Raft cluster)
- 4647: Nomad cluster communication (used for communication between Nomad clients and servers)
*/

locals {
  vault_tcp_ports = {
    "vault_api"     = 8200
    "vault_raft"    = 8201
    #"nomad_cluster" = 4647
  }
}

resource "aws_security_group_rule" "vault_tcp_ingress" {
  for_each = local.vault_tcp_ports
  type              = "ingress"
  from_port         = each.value
  to_port           = each.value
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.nomad_sg.id
  #cidr_blocks       = ["10.0.0.0/16"] # Replace with your VPC CIDR or specific IP range
  description       = "Allow TCP communication on port ${each.value} for ${each.key}"
}

### Ingress Rules for UDP Ports

/*
This rule allows inbound UDP communication for the following port:
- 53: DNS internal communication (used for internal DNS queries within the VPC)
*/

locals {
  vault_udp_ports = {
    "dns_internal" = 53
  }
}

resource "aws_security_group_rule" "vault_udp_ingress" {
  for_each = local.vault_udp_ports
  type              = "ingress"
  from_port         = each.value
  to_port           = each.value
  protocol          = "udp"
  security_group_id = aws_security_group.nomad_sg.id
  self              = true
  #cidr_blocks       = ["10.0.0.0/16"] # Replace with your VPC CIDR or specific IP range
  description       = "Allow UDP communication on port ${each.value} for ${each.key}"
}


# Allow ingress from the bastion security group
resource "aws_security_group_rule" "vault_ingress_from_bastion" {
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  description = "Allow inbound TCP communication on port 8200 from the bastion security group"
  security_group_id        = aws_security_group.nomad_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
}


