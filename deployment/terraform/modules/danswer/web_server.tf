resource "aws_ecs_service" "web_service" {
  name            = "danswer-web-service"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.web_service.arn
  desired_count   = 1
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
}

resource "aws_ecs_task_definition" "web_service" {
  family             = "web_service"
  task_role_arn      = aws_iam_role.ecs_task_execution_role.arn
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  network_mode       = "bridge"
  requires_compatibilities = ["EXTERNAL", "EC2"]

  placement_constraints {
    type = "memberOf"
    expression = "attribute:ecs.capability.external !exists"
  }

  # Reading the container definition from the file
  container_definitions = templatefile("${path.module}/task_defs/web_server.json", {
    aws_region  = data.aws_region.current.name
    aws_acct_id = data.aws_caller_identity.current.account_id
  })
}

# web_server ssm parameters
resource "aws_ssm_parameter" "next_public_disable_streaming" {
  name        = "NEXT_PUBLIC_DISABLE_STREAMING"
  description = "Disable streaming in the frontend application."
  type        = "String"
  value = "false"
}

resource "aws_ssm_parameter" "next_public_new_chat_directs_to_same_persona" {
  name        = "NEXT_PUBLIC_NEW_CHAT_DIRECTS_TO_SAME_PERSONA"
  description = "New chat sessions direct to the same persona."
  type        = "String"
  value = "false"
}

resource "aws_ssm_parameter" "next_public_positive_feedback_options" {
  name        = "NEXT_PUBLIC_POSITIVE_PREDEFINED_FEEDBACK_OPTIONS"
  description = "Positive feedback options in the frontend."
  type        = "StringList"
  value = "[]"
}

resource "aws_ssm_parameter" "next_public_negative_feedback_options" {
  name        = "NEXT_PUBLIC_NEGATIVE_PREDEFINED_FEEDBACK_OPTIONS"
  description = "Negative feedback options in the frontend."
  type        = "StringList"
  value = "[]"
}

resource "aws_ssm_parameter" "next_public_disable_logout" {
  name        = "NEXT_PUBLIC_DISABLE_LOGOUT"
  description = "Disable the logout functionality in the frontend."
  type        = "String"
  value = "false"
}

resource "aws_ssm_parameter" "next_public_sidebar_open" {
  name        = "NEXT_PUBLIC_DEFAULT_SIDEBAR_OPEN"
  description = "Set the default state of the sidebar to open."
  type        = "String"
  value = "true"
}

resource "aws_ssm_parameter" "next_public_theme" {
  name        = "NEXT_PUBLIC_THEME"
  description = "Theme setting for the frontend (e.g., light, dark)."
  type        = "String"
  value       = "dark"
}

resource "aws_ssm_parameter" "next_public_danswer_toggle" {
  name        = "NEXT_PUBLIC_DO_NOT_USE_TOGGLE_OFF_DANSWER_POWERED"
  description = "Disable the toggle to turn off 'Danswer Powered' branding."
  type        = "String"
  value = "false"
}

resource "aws_ssm_parameter" "web_domain" {
  name  = "WEB_DOMAIN"
  type  = "String"
  value = "localhost"
}

resource "aws_ssm_parameter" "theme_is_dark" {
  name        = "THEME_IS_DARK"
  type        = "String"
  description = "Indicates if the default theme is dark."
  value = "true"
}

resource "aws_ssm_parameter" "disable_llm_doc_relevance" {
  name        = "DISABLE_LLM_DOC_RELEVANCE"
  type        = "String"
  description = "Disable LLM document relevance ranking."
  value = "false"
}

resource "aws_ssm_parameter" "enable_paid_enterprise_features" {
  name  = "ENABLE_PAID_ENTERPRISE_EDITION_FEATURES"
  type  = "String"
  value = "false"
}