# Listener block for client
listener "tcp" {
  # The client listens locally on the loopback interface
  address     = "127.0.0.1:8200"
  tls_disable = "true"
}

# Point to the Vault server's API address
vault {
  address = "http://${leader_ip}:8200"
}

# Disable mlock for non-root user environments (for development purposes)
disable_mlock = true
