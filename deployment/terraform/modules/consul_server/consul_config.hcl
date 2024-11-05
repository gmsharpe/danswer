node_name = "${node_name}"
datacenter = "${datacenter}"
connect {
  enabled = true
}
enable_central_service_config = true

%{ if tls }
ca_file  = "/consul/consul-agent-ca.pem"
cert_file = "/consul/${datacenter}-server-consul-0.pem"
key_file = "/consul/${datacenter}-server-consul-0-key.pem"
auto_encrypt = {
  allow_tls = true
}

%{ if is_consul_1_14_plus }
ports {
  https    = 8501
  grpc_tls = 8503
}
%{ else }
ports {
  https = 8501
  grpc  = 8502
}
%{ endif }

verify_incoming_rpc    = true
verify_outgoing        = true
verify_server_hostname = true
%{ else }
ports {
  grpc = 8502
}
%{ endif }

%{ if acls }
acl {
enabled                   = true
default_policy            = "deny"
down_policy               = "extend-cache"
enable_token_persistence  = true

tokens = {
master = "${bootstrap_token}"
agent  = "${bootstrap_token}"
%{ if replication_token != "" }
replication = "${replication_token}"
%{ endif }
}

%{ if enable_mesh_gateway_wan_federation }
enable_token_replication = true
%{ endif }
}
%{ endif }

%{ if primary_datacenter != "" }
primary_datacenter = "${primary_datacenter}"
%{ endif }

%{ if length(retry_join_wan) > 0 }
retry_join_wan = [
%{ for addr in retry_join_wan }
"${addr}",
%{ endfor }
]
%{ endif }

%{ if enable_mesh_gateway_wan_federation }
connect {
enable_mesh_gateway_wan_federation = true
}
%{ endif }

%{ if enable_cluster_peering }
peering {
enabled = true
}
%{ endif }

%{ if length(primary_gateways) > 0 }
primary_gateways = [
%{ for addr in primary_gateways }
"${addr}",
%{ endfor }
]
%{ endif }
