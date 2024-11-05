output "consul_secret_id" {
  value = aws_secretsmanager_secret.bootstrap_token[0].id
}