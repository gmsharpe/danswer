# Listener block for client
listener "tcp" {
  # The client listens locally on the loopback interface
  address     = "127.0.0.1:8200"
  tls_disable = "${tls_disable}"
}

# Point to the Vault server's API address
vault {
  address = "http://${leader_ip}:8200"
}

backend "consul" {
  scheme  = "http"
  address = "${consul_ip_address}:8500"
  path    = "vault/"
  service = "vault"
  datacenter = "${datacenter}"
}

# Disable mlock for non-root user environments (for development purposes)
disable_mlock = true
