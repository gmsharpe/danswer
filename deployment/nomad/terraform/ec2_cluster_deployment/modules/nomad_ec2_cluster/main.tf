provider "aws" {
  region = "us-west-1"
}

data "aws_availability_zones" "available" {}

data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

### VPC, SUBNET, NOMAD & BASTION CONFIGURATION

resource "aws_vpc" "nomad_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "nomad_vpc"
  }
}
resource "aws_subnet" "nomad_subnet" {
  vpc_id                  = aws_vpc.nomad_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[0]  # Use the first available zone

  tags = {
    Name = "nomad_subnet"
  }
}
resource "aws_subnet" "bastion_subnet" {
  vpc_id                  = aws_vpc.nomad_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[0]  # Use the first available zone
  tags = {
    Name = "bastion_subnet"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.nomad_vpc.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_security_group" "nomad_sg" {
  name        = "nomad_sg"
  description = "Allow Nomad cluster traffic"
  vpc_id      = aws_vpc.nomad_vpc.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    self      = true
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # Allow Nomad HTTP API communication
  ingress {
    from_port = 4646
    to_port   = 4646
    protocol  = "tcp"
    self      = true
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # Allow Nomad RPC communication
  ingress {
    from_port = 4647
    to_port   = 4647
    protocol  = "tcp"
    self      = true
  }

  # Allow Nomad Gossip protocol communication (TCP and UDP)
  ingress {
    from_port = 4648
    to_port   = 4648
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 4648
    to_port   = 4648
    protocol  = "udp"
    self      = true
  }

  # This is used for communication between Consul agents (clients and servers) on the same LAN for 
  #  gossip protocol and agent coordination. (TCP and UDP)
  ingress {
    from_port = 8301
    to_port   = 8301
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 8301
    to_port   = 8301
    protocol  = "udp"
    self      = true
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
  }

  # This is used for HTTP access to the Consul API and the Web UI (if enabled).
  ingress {
    from_port = 8500
    to_port   = 8500
    protocol  = "tcp"
    self      = true
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    from_port = 8200
    to_port   = 8200
    protocol  = "tcp"
    self      = true
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Security group for SSH access to bastion"
  vpc_id      = aws_vpc.nomad_vpc.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # aws_eip.bastion_eip.address] # Consider restricting this to your IP for security
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["10.0.0.0/16"] # Allows access to the entire VPC
  }

  tags = {
    Name = "bastion_sg"
  }
}
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.nomad_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}
resource "aws_route_table_association" "nomad_public_rta" {
  subnet_id      = aws_subnet.nomad_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "bastion_public_rta" {
  subnet_id      = aws_subnet.bastion_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_instance" "bastion_host" {
  ami           = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = var.bastion_instance_type
  subnet_id     = aws_subnet.bastion_subnet.id
  key_name      = var.key_name
  security_groups = [aws_security_group.bastion_sg.id]

  lifecycle {
    ignore_changes = [
      security_groups,
      user_data
    ]
  }

  tags = {
    Name = "bastion-host",
    Project = "Danswer-Bastion"
  }
  depends_on = [aws_eip.bastion_eip]

}

resource "aws_eip" "bastion_eip" {

  tags = {
    Name = "bastion-eip"
  }
  lifecycle {
    ignore_changes = [
      tags,
      allocation_id
    ]
  }
}

# Associate the Elastic IP with the EC2 instance
resource "aws_eip_association" "bastion_eip_assoc" {
  instance_id   = aws_instance.bastion_host.id
  allocation_id = aws_eip.bastion_eip.id
  lifecycle {
    ignore_changes = [
      allocation_id
    ]
  }
  depends_on = [aws_instance.bastion_host, aws_eip.bastion_eip]
}

resource "aws_instance" "nomad_instance" {
  count         = 3
  ami           = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = var.nomad_instance_type
  subnet_id     = aws_subnet.nomad_subnet.id
  security_groups = [aws_security_group.nomad_sg.id]
  key_name      = var.key_name
  private_ip    = "10.0.1.${count.index + 10}"

  user_data = templatefile("${path.module}/nomad_user_data.tpl", {
    count           = count.index
    ip_address      = "10.0.1.${count.index + 10}"
    server_ip       = "10.0.1.10"
    install_consul  = var.install_consul
    install_nomad = var.install_nomad
    install_vault   = var.install_vault
    run_user_data_script = true
    vault_override  = true
    consul_override = true
    nomad_override  = true
    is_server       = count.index == 0 ? true : false # update this with more appropriate logic
    is_client       = true # update this with more appropriate logic
    name            = "danswer-vault"
    nomad_server_config   = templatefile("${path.module}/shared_configurations/nomad/config/nomad_server.hcl", {
      ip_address   = "10.0.1.${count.index + 10}"
      server_count = 3
      vault_ip_address     = "10.0.1.10"
      token_for_nomad = ""
      task_token_ttl  = "1h"
      consul_ip_address = "10.0.1.10"
      datacenter      = "ats-1"
    })
    nomad_client_config = templatefile("${path.module}/shared_configurations/nomad/config/nomad_client.hcl", {
      ip_address = "10.0.1.${count.index + 10}"
      vault_ip_address  = "10.0.1.10"
      datacenter      = "ats-1"
      node_pool  = "danswer"
      consul_ip_address = "10.0.1.10"
    })
    nomad_server_and_client_config = templatefile("${path.module}/shared_configurations/nomad/config/nomad_server_and_client.hcl", {
      ip_address   = "10.0.1.${count.index + 10}"
      server_count = 1
      vault_ip_address     = "10.0.1.10"
      token_for_nomad = ""
      task_token_ttl  = "1h"
      node_pool  = "danswer"
      datacenter      = "ats-1"
      consul_ip_address = "10.0.1.10"
      server_ips = jsonencode(["10.0.1.10", "10.0.1.11", "10.0.1.12"])
    })
    consul_config   = templatefile("${path.module}/shared_configurations/consul/config/consul.hcl", {
      private_ip      = "10.0.1.${count.index + 10}"
      server_ips      = jsonencode(["10.0.1.10", "10.0.1.11", "10.0.1.12"])
      datacenter      = "ats-1"
      server_count    = 3
    })
    vault_server_config    = templatefile("${path.module}/shared_configurations/vault/config/vault_server.hcl", {
      leader_ip       = "10.0.1.10"
      private_ip      = "10.0.1.${count.index + 10}"
      consul_ip_address = "10.0.1.10"
      datacenter      = "ats-1"
      tls_disable     = true
      consul_ip_address       = "10.0.1.10"
    })
    vault_client_config    = templatefile("${path.module}/shared_configurations/vault/config/vault_client.hcl", {
      leader_ip       = "10.0.1.10"
      consul_ip_address       = "10.0.1.10"
      datacenter      = "ats-1"
      tls_disable     = true
    })
  })
  user_data_replace_on_change = true

  tags = {
    Name    = count.index == 0 ? "NomadInstance-Server-${count.index}" : "NomadInstance-${count.index}"
    Project = "Danswer"
  }

  lifecycle {
    ignore_changes = [
      security_groups
    ]
  }

  root_block_device {
    volume_size           = 15
    volume_type           = "gp2"
    delete_on_termination = true
  }

  # Add Elastic Block Store (EBS) volume
#   ebs_block_device {
#     device_name = "/dev/xvdf"
#     volume_size = 15 # Size in GB
#     volume_type = "gp2" # General Purpose SSD
#     delete_on_termination = true # Ensures volume is deleted when instance is terminated
#   }

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

}

# Create IAM Role
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-ssm-secrets-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach Policy to IAM Role
resource "aws_iam_role_policy" "ssm_secrets_policy" {
  name   = "EC2SSMSecretsPolicy"
  role   = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParameterHistory",
          "ssm:DeleteParameter",
        ],
        "Resource": "arn:aws:ssm:*:*:parameter/*"
      }
    ]
  })
}

# Create Instance Profile
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2-ssm-instance-profile"
  role = aws_iam_role.ec2_ssm_role.name
}





# variable "local_port1" {
#   default = 14646
# }
#
# variable "local_port2" {
#   default = 18500
# }
#
# variable "remote_host" {
#   default = "10.0.1.10"
# }
#
# variable "ec2_host" {
#   default = "ec2-54-151-43-228.us-west-1.compute.amazonaws.com"
# }
#
# variable "user" {
#   default = "ec2-user"
# }
#
# # Generate the PowerShell SSH tunnel script
# data "template_file" "ssh_script" {
#   template = <<EOF
# # PowerShell SSH tunnel script
# Start-Process "ssh" -ArgumentList "-L $${local_port1}:$${remote_host}:$${local_port1} -L $${local_port2}:$${remote_host}:$${local_port2} $${user}@$${ec2_host} -N" -NoNewWindow
# EOF
#
#   vars = {
#     local_port1   = var.local_port1
#     local_port2   = var.local_port2
#     remote_host   = var.remote_host
#     ec2_host      = var.ec2_host
#     user          = var.user
#   }
# }
#
#
# # Write the PowerShell script to a file
# resource "local_file" "ssh_script" {
#   filename = "${path.module}/ssh-tunnel.ps1"
#   content  = data.template_file.ssh_script.rendered
# }
#
# # Execute the PowerShell script
# resource "null_resource" "run_ssh_tunnel" {
#   provisioner "local-exec" {
#     command = "powershell.exe -ExecutionPolicy Bypass -File ${local_file.ssh_script.filename}"
#   }
#
#   triggers = {
#     always_run = "${timestamp()}"
#   }
#   depends_on = [aws_instance.bastion_host, aws_instance.nomad_instance, local_file.ssh_script]
# }