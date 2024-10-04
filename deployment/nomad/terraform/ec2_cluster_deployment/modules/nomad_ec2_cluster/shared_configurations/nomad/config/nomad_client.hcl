# Based on a standard Nomad client configuration file provided by Hashicorp
#   https://github.com/hashicorp/nomad-guides/blob/master/application-deployment/microservices/shared/config/nomad_client.hcl
#
# The following variables need to be set via replacement (e.g. sed) before starting the Nomad client:
# - $ip_address
# - VAULT_URL
# - node_pool

data_dir = "/opt/nomad/data"
bind_addr = "${ip_address}"
name = "nomad@${ip_address}"

# Enable the client
client {
  enabled = true
  options = {
    driver.java.enable = true
    # Using this setting can introduce security risks if not managed carefully, as tasks will have direct access to the
    # host's resources and can potentially compromise the system. It's generally recommended to use containerization
    # (e.g. driver.exec) whenever possible for better isolation and security.
    driver.raw_exec.enable = true
    driver.exec.enable = true
    docker.cleanup.image = false
  }
  node_pool  = "${node_pool}"
  meta {
    node_pool = "${node_pool}"
  }
}

advertise {
  http = "${ip_address}"
  rpc = "${ip_address}"
  serf = "${ip_address}"
}

consul {
  address = "${consul_ip_address}:8500"
}

# vault {
#   enabled = true
#   address = "${vault_ip_address}"
# }

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
}