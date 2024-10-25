resource "aws_ecs_task_definition" "consul_server" {
  family             = "consul_server"
  task_role_arn      = aws_iam_role.ecs_task_execution_role.arn
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  network_mode       = "bridge"
  requires_compatibilities = ["EC2", "EXTERNAL"]

  container_definitions = jsonencode([
    jsondecode(templatefile("${path.module}/task_defs/consul_server.json", {
      aws_region  = data.aws_region.current.name
      aws_acct_id = data.aws_caller_identity.current.account_id
    }))
  ])

  volume {
    name      = "consul-data"
    host_path = "/etc/consul/data"
  }
  volume {
    name      = "consul-config"
    host_path = "/etc/consul/config"
  }
}
