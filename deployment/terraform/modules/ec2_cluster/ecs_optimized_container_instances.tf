data "aws_ssm_parameter" "ecs_al2023_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

resource "aws_instance" "ecs_anywhere_instance" {
  ami           = data.aws_ssm_parameter.ecs_al2023_ami.value  # Use ECS-optimized AL2023 AMI
  instance_type = var.node_instance_type
  subnet_id     = aws_subnet.ecs_anywhere_subnet.id
  security_groups = [aws_security_group.ecs_anywhere_sg.id]
  key_name      = var.key_name
  private_ip    = "10.0.2.${count.index + 10}"

  user_data = templatefile("${path.module}/ecs_optimized_user_data.tpl", {
    cluster_name    = aws_ecs_cluster.hybrid_cluster.name
  })
  user_data_replace_on_change = true

  tags = {
    Name    = "ecsAnywhereInstance-${count.index}"
    Project = "Danswer"
  }

  root_block_device {
    volume_size           = 25
    volume_type           = "gp2"
    delete_on_termination = true
  }

  iam_instance_profile = aws_iam_instance_profile.ecs_cluster_instance_profile.name
}

# Create Instance Profile
resource "aws_iam_instance_profile" "ecs_cluster_instance_profile" {
  name = "ecs-anywhere-instance-profile"
  role = aws_iam_role.ecs_anywhere_mngmt_role.name
}