
# Configuration is based on:
#   https://github.com/hashicorp/nomad-guides/blob/master/application-deployment/microservices/shared/config/nomad.hcl
#
# This file is used to configure the Nomad server. It is used by the Nomad server to connect to the Consul server and Vault server.
# The server block is used to enable the server and set the number of servers to expect.
# The following variables need to be set via replacement (e.g. sed) before starting the Nomad server:
# - ip_address
# - server_count
# - vault_ip
# - token_for_nomad
# - consul_ip_address
# - task_token_ttl

data_dir = "/opt/nomad/data"
bind_addr = "${ip_address}"

ui {
  enabled = true
}

# enable the server
server {
  enabled = true
  bootstrap_expect = "${server_count}"
}

name = "nomad@${ip_address}"

consul {
  address = "${consul_ip_address}:8500"
}

vault {
  enabled = true
  address = "${vault_ip_address}:8200"
  task_token_ttl = "${task_token_ttl}" # e.g. "1h"
  create_from_role = "nomad-cluster"
  token = "${token_for_nomad}"
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
}

advertise {
  http = "${ip_address}"
  rpc  = "${ip_address}"
  serf = "${ip_address}"
}