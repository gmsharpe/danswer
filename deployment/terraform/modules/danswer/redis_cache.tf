resource "aws_ecs_service" "redis_cache" {
  name            = "redis-cache"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.redis_cache.arn
  desired_count   = 1
  launch_type     = "EXTERNAL"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
}


resource "aws_ecs_task_definition" "redis_cache" {
  family                   = "redis_cache"
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "bridge"
  requires_compatibilities = ["EXTERNAL"]

  # Reading the container definition from the file
  container_definitions = templatefile("${path.module}/task_defs/redis_cache.json", {
    aws_region = data.aws_region.current.name
    aws_acct_id = data.aws_caller_identity.current.account_id
  })
  volume {
    name = "redis_data"
    host_path = "/redis/data"
  }
}