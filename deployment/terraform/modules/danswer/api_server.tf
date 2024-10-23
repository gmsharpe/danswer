resource "aws_ecs_service" "api_server" {
  name            = "api_server"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.api_server.arn
  desired_count   = 1
  launch_type     = "EXTERNAL"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
}

resource "aws_ecs_task_definition" "api_server" {
  family                   = "api_server"
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "bridge"
  requires_compatibilities = ["EXTERNAL"]

  # Reading the container definition from the file
  container_definitions = templatefile("${path.module}/task_defs/api_server.json", {
    aws_region = data.aws_region.current.name
    aws_acct_id = data.aws_caller_identity.current.account_id
  })
}

# api_server ssm parameters
#       {
#        "name": "MIN_THREADS_ML_MODELS",
#        "valueFrom": "arn:aws:ssm:${aws_region}:${aws_acct_id}:parameter/MIN_THREADS_ML_MODELS"
#      },
#      {
#        "name": "LOG_LEVEL",
#        "valueFrom": "arn:aws:ssm:${aws_region}:${aws_acct_id}:parameter/LOG_LEVEL"
#      },
#      {
#        "name": "DISABLE_MODEL_SERVER",
#        "valueFrom": "arn:aws:ssm:${aws_region}:${aws_acct_id}:parameter/DISABLE_MODEL_SERVER"
#      }

resource "aws_ssm_parameter" "min_threads_ml_models" {
  name        = "MIN_THREADS_ML_MODELS"
  description = "Minimum number of threads for ML models."
  type        = "String"
  value = "1"
}

resource "aws_ssm_parameter" "log_level" {
  name        = "LOG_LEVEL"
  description = "Log level for the application."
  type        = "String"
  value = "DEBUG"
}

resource "aws_ssm_parameter" "disable_model_server" {
  name        = "DISABLE_MODEL_SERVER"
  description = "Disable the model server."
  type        = "String"
  value = "false"
}
