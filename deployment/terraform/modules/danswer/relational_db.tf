# resource "aws_ecs_service" "relational_db_service" {
#   name            = "relational-db-service"
#   cluster         = var. cluster_arn
#   task_definition = aws_ecs_task_definition.relational_db.arn
#   desired_count   = 1
#   launch_type     = "EXTERNAL"
#
#   deployment_minimum_healthy_percent = 100
#   deployment_maximum_percent         = 200
#
# }
#
# resource "aws_ecs_task_definition" "relational_db" {
#   family                   = "relational_db"
#   task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
#   execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
#   network_mode             = "bridge"
#   requires_compatibilities = ["EXTERNAL"]
#
#   # Reading the container definition from the file
#   container_definitions = templatefile("${path.module}/task_defs/relational_db.json", {
#     aws_region = data.aws_region.current.name
#     aws_acct_id = data.aws_caller_identity.current.account_id
#   })
#   volume {
#     name = "db"
#     host_path = "/db"
#   }
# }


# Storing POSTGRES_USER in SSM Parameter Store
resource "aws_ssm_parameter" "postgres_user" {
  name        = "DANSWER_POSTGRES_USER"  # Adjust the name as needed
  type        = "SecureString"          # Ensure this is encrypted
  value       = "your_username"         # Replace with the actual username or leave blank for runtime injection
  description = "Postgres database user"
}

# Storing POSTGRES_PASSWORD in SSM Parameter Store
resource "aws_ssm_parameter" "postgres_password" {
  name        = "DANSWER_POSTGRES_PASSWORD"  # Adjust the name as needed
  type        = "SecureString"              # Ensure this is encrypted
  value       = "your_password"             # Replace with the actual password or leave blank for runtime injection
  description = "Postgres database password"
}
