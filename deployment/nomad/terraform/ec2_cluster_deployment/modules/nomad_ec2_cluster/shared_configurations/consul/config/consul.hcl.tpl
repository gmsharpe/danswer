data_dir = "/opt/consul"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "${private_ip}"
retry_join = ${server_ips}
datacenter = "dc1"

# server settings
server = true
bootstrap_expect = 3
ui_config {
  enabled = true
}