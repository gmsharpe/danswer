

provider "vault" {
  address = "http://127.0.0.1:18200"
  token   = var.vault_root_token
}
provider "nomad" {
  address = "http://127.0.0.1:14646"
}