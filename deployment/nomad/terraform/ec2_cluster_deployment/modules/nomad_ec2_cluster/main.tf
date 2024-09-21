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
    Project = "Danswer"
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
    count           = count.index,
    private_ip      = "10.0.1.${count.index + 10}",
    server_ip       = "10.0.1.10"
    install_consul  = var.install_consul
    install_danswer = var.install_danswer
    install_vault   = var.install_vault
    run_user_data_script = "true"
  })

  tags = {
    Name = "NomadInstance-${count.index == 0 ? "Server" : ""}-${count.index}",
    Project = "Danswer"
  }

  lifecycle {
    ignore_changes = [
      security_groups, user_data
    ]
  }

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