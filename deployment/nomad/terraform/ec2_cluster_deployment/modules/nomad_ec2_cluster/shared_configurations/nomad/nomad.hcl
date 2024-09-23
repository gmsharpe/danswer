# Configuration is based on:
#   https://github.com/hashicorp/nomad-guides/blob/master/application-deployment/microservices/shared/config/nomad.hcl
#
# This file is used to configure the Nomad server. It is used by the Nomad server to connect to the Consul server and Vault server.
# The server block is used to enable the server and set the number of servers to expect.
# The following variables need to be set via replacement (e.g. sed) before starting the Nomad server:
# - IP_ADDRESS
# - SERVER_COUNT
# - VAULT_URL
# - TOKEN_FOR_NOMAD

data_dir = "/opt/nomad/data"
bind_addr = "IP_ADDRESS"

ui {
  enabled = true
}

# Enable the server
server {
  enabled = true
  bootstrap_expect = SERVER_COUNT
}

name = "nomad@IP_ADDRESS"

consul {
  address = "IP_ADDRESS:8500"
}

vault {
  enabled = true
  address = "VAULT_URL"
  task_token_ttl = "1h"
  create_from_role = "nomad-cluster"
  token = "TOKEN_FOR_NOMAD"
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
}

advertise {
  http = "IP_ADDRESS"
  rpc = "IP_ADDRESS"
  serf = "IP_ADDRESS"
}