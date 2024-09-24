data_dir = "/opt/consul"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "$PRIVATE_IP"
retry_join = ${SERVER_IPS}
datacenter = "dc1"