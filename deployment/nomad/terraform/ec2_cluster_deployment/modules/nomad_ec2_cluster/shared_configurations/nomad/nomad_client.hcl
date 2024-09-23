# Based on a standard Nomad client configuration file provided by Hashicorp
#   https://github.com/hashicorp/nomad-guides/blob/master/application-deployment/microservices/shared/config/nomad_client.hcl
#
# The following variables need to be set via replacement (e.g. sed) before starting the Nomad client:
# - IP_ADDRESS
# - VAULT_URL
# - NODE_POOL

data_dir = "/opt/nomad/data"
bind_addr = "IP_ADDRESS"
name = "nomad@IP_ADDRESS"

# Enable the client
client {
  enabled = true
  options = {
    driver.java.enable = "1"
    # Using this setting can introduce security risks if not managed carefully, as tasks will have direct access to the
    # host's resources and can potentially compromise the system. It's generally recommended to use containerization
    # (e.g. driver.exec) whenever possible for better isolation and security.
    driver.raw_exec.enable = "true"
    driver.exec.enable = "true"
    docker.cleanup.image = false
  }
  node_pool  = "NODE_POOL"
  meta {
    node_pool = "NODE_POOL"
  }
}

advertise {
  http = "IP_ADDRESS"
  rpc = "IP_ADDRESS"
  serf = "IP_ADDRESS"
}

consul {
  address = "IP_ADDRESS:8500"
}

vault {
  enabled = true
  address = "VAULT_URL"
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
}