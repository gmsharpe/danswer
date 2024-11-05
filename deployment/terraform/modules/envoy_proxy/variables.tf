variable "tls_enabled" {
  default = "true"
}
variable "consul_server_ip" {
  default = "10.0.1.67"
}
variable "consul_home" {
  default = "/consul"
}

variable "consul_version" {
  default = "1.20.1"
}

variable "service_name" {
  default = ""
}

variable "consul_token_secret_id" { }

variable "consul_ca_cert_secret_id" { }

# variable "consul_client_cert_secret_id" { }

variable "consul_server_cert_secret_id" { }

variable "consul_client_key_secret_id" { }