

provider "vault" {
  address = "http://127.0.0.1:18200"
  token   = data.aws_ssm_parameter.vault_root_token.insecure_value
}
provider "nomad" {
  address = "http://127.0.0.1:14646"
}