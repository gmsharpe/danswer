data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
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

resource "aws_instance" "ecs_anywhere_instance" {
  count         = 2
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

  user_data = templatefile("${path.module}/user_data/external_simulated_user_data.tpl", {
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

  # DO NOT ADD instance profile if simulating 'external' ecs container instances
  #iam_instance_profile =

}