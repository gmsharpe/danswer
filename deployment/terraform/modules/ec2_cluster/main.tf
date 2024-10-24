provider "aws" {
  region = "us-west-1"
}

data "aws_availability_zones" "available" {}

data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

### VPC, SUBNET, NOMAD & BASTION CONFIGURATION

resource "aws_vpc" "ecs_anywhere_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "ecs_anywhere_vpc"
  }
}
resource "aws_subnet" "ecs_anywhere_subnet" {
  vpc_id                  = aws_vpc.ecs_anywhere_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[0]  # Use the first available zone

  tags = {
    Name = "ecs_anywhere_subnet"
  }
}
resource "aws_subnet" "bastion_subnet" {
  vpc_id                  = aws_vpc.ecs_anywhere_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[0]  # Use the first available zone
  tags = {
    Name = "bastion_subnet"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ecs_anywhere_vpc.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_security_group" "ecs_anywhere_sg" {
  name        = "ecs_anywhere_sg"
  description = "Allow Nomad cluster traffic"
  vpc_id      = aws_vpc.ecs_anywhere_vpc.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    self      = true
    security_groups = [aws_security_group.danswer_bastion_sg.id]
  }

  ingress {
    description = "All traffic within security group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # All protocols
    self        = true  # Traffic from instances with the same security group
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.ecs_anywhere_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}
resource "aws_route_table_association" "ecs_anywhere_public_rta" {
  subnet_id      = aws_subnet.ecs_anywhere_subnet.id
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

# ECS Cluster

resource "aws_ecs_cluster" "hybrid_cluster" {
  name = "hybrid-ecs-cluster"

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

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_instance" "ecs_anywhere_instance" {
  count         = 0
  ami           = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = var.node_instance_type
  subnet_id     = aws_subnet.ecs_anywhere_subnet.id
  security_groups = [aws_security_group.ecs_anywhere_sg.id]
  key_name      = var.key_name
  private_ip    = "10.0.1.${count.index + 10}"

#   metadata_options {
#     http_tokens   = "optional"      # Enforces the use of IMDSv2
#     http_put_response_hop_limit = 2 # Optional: limits the number of network hops allowed for IMDS requests
#     http_endpoint = "enabled"       # Ensure the metadata service is enabled
#   }

  user_data = templatefile("${path.module}/user_data.tpl", {
    count           = count.index
    ip_address      = "10.0.1.${count.index + 10}"
    server_ip       = "10.0.1.10"
    is_server       = count.index == 0 ? true : false # update this with more appropriate logic
    is_client       = true # update this with more appropriate logic
    aws_region      = data.aws_region.current.name
    aws_acct_id  = data.aws_caller_identity.current.account_id
    ssm_activation_id = aws_ssm_activation.activation.id
    ssm_activation_code = aws_ssm_activation.activation.activation_code
    cluster_name    = aws_ecs_cluster.hybrid_cluster.name
    #ecs_version = "1.87.0-1"
  })
  user_data_replace_on_change = true

  tags = {
    Name    = count.index == 0 ? "ecsAnywhereInstance-Server-${count.index}" : "ecsAnywhereInstance-${count.index}"
    Project = "Danswer"
  }

  lifecycle {
    ignore_changes = [
      security_groups
    ]
  }

  root_block_device {
    volume_size           = 25
    volume_type           = "gp2"
    delete_on_termination = true
  }

  #iam_instance_profile = aws_iam_instance_profile.ecs_cluster_instance_profile.name

}

# Create IAM Role
resource "aws_iam_role" "ecs_cluster_instance_role" {
  name = "ecs-anywhere-ssm-secrets-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ecs.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      },
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      },
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ssm.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_cluster_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}


# Create Instance Profile
resource "aws_iam_instance_profile" "ecs_cluster_instance_profile" {
  name = "ecs-anywhere-instance-profile"
  role = aws_iam_role.ecs_cluster_instance_role.name
}

#resource "aws_iam_role" "ssm_managed_instance_role" {
#   name = "ssmManagedInstanceRole"
#
#   assume_role_policy = jsonencode({
#     "Version": "2012-10-17",
#     "Statement": [
#       {
#         "Action": "sts:AssumeRole",
#         "Principal": {
#           "Service": "ssm.amazonaws.com"
#         },
#         "Effect": "Allow",
#         "Sid": ""
#       }
#     ]
#   })
# }

data "aws_iam_policy_document" "ssm_managed_instance_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com", "ssm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_role_policy" {
  role       = aws_iam_role.ecs_cluster_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/hybrid-cluster"
  retention_in_days = 7
}