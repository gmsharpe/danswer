storage "raft" {
  path    = "/opt/vault/data"
  node_id = "vault-node-${private_ip}"

  retry_join {
    leader_api_addr = "http://${leader_ip}:8201"
  }
}

# https://www.vaultproject.io/docs/configuration/storage/consul.html
backend "consul" {
  scheme  = "http"
  address = "${consul_ip_address}:8500"
  path    = "vault/"
  service = "vault"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = "${tls_disable}"  # Consider enabling TLS
}

api_addr     = "http://${private_ip}:8200"
cluster_addr = "http://${private_ip}:8201"

ui            = true
disable_mlock = true