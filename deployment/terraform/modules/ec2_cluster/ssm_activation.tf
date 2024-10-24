resource "aws_ssm_activation" "activation" {
  name               = "ecs-anywhere-activation"
  description        = "Activation code for on-premises instances"
  iam_role           = aws_iam_role.ecs_anywhere_mngmt_role.name
  registration_limit = var.registration_limit
  expiration_date    = var.expiration_date
}

output "activation_code" {
  value = aws_ssm_activation.activation.activation_code
}

output "activation_id" {
  value = aws_ssm_activation.activation.id
}