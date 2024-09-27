# configuration is based on:
#   https://github.com/hashicorp/nomad-guides/blob/master/application-deployment/microservices/shared/config/nomad.hcl
#
# this file is used to configure the nomad server. it is used by the nomad server to connect to the consul server and vault server.
# the server block is used to enable the server and set the number of servers to expect.
# the following variables need to be set via replacement (e.g. sed) before starting the nomad server:
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

client {
  enabled = true
  servers = ${server_ips}
  node_pool  = "$node_pool"
  meta {
    node_pool = "$node_pool"
  }
  options {
    "driver.raw_exec.enable" = "true"
    "driver.exec.enable" = "true"
    "driver.docker.enable" = "true"
  }
}

