data_dir = "/opt/consul"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "${private_ip}"
retry_join = ${server_ips} # array of IPs
datacenter = "${datacenter}"