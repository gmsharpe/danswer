resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ecs_anywhere_vpc.id

  tags = {
    Name = "main-igw"
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

resource "aws_route_table_association" "ecs_anywhere_public_rta" {
  subnet_id      = aws_subnet.ecs_anywhere_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ECS Cluster

resource "aws_ecs_cluster" "hybrid_cluster" {
  name = "hybrid-ecs-cluster"

}

resource "aws_iam_role" "ecs_anywhere_mngmt_role" {
  name = "ecs-anywhere-mngmt-role"
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

resource "aws_iam_role_policy_attachment" "ec2_container_service_for_ec2_role_policy" {
  role       = aws_iam_role.ecs_anywhere_mngmt_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core_role_policy" {
  role       = aws_iam_role.ecs_anywhere_mngmt_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/hybrid-cluster"
  retention_in_days = 7
}