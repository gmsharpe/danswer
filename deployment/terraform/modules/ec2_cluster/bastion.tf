resource "aws_subnet" "bastion_subnet" {
  vpc_id                  = aws_vpc.ecs_anywhere_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[0]  # Use the first available zone
  tags = {
    Name = "bastion_subnet"
  }
}


resource "aws_security_group" "danswer_bastion_sg" {
  name        = "danswer_bastion_sg"
  description = "Security group for SSH access to bastion"
  vpc_id      = aws_vpc.ecs_anywhere_vpc.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Consider restricting this to your IP for security
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

resource "aws_route_table_association" "bastion_public_rta" {
  subnet_id      = aws_subnet.bastion_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_instance" "bastion_host" {
  ami           = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = var.bastion_instance_type
  subnet_id     = aws_subnet.bastion_subnet.id
  key_name      = var.key_name
  security_groups = [aws_security_group.danswer_bastion_sg.id]

  lifecycle {
    ignore_changes = [
      security_groups,
      user_data
    ]
  }

  tags = {
    Name = "danswer-bastion-host",
    Project = "Danswer-Bastion"
  }
  depends_on = [aws_eip.bastion_eip]

}

resource "aws_eip" "bastion_eip" {

  tags = {
    Name = "danswer-bastion-eip"
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