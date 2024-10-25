#!/bin/bash

AWS_REGION=$${AWS_REGION:-"us-west-1"}

# Update the system
sudo yum update -y

# needed to run gpg-agent on Amazon Linux
echo "installing gnupg2"
sudo yum install gnupg2 -y --allowerasing
sudo gpg-agent --daemon

# The latest install scripts fails when trying to touch the /etc/ecs/ecs.config file
sudo mkdir -p "/etc/ecs"

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/instance-details-tags.html#instance-details-tags-external
# cat <<'EOF' >> /etc/ecs/ecs.config
#ECS_CLUSTER=MyCluster
#ECS_CONTAINER_INSTANCE_TAGS={"tag_key": "tag_value"}
#ECS_CONTAINER_INSTANCE_PROPAGATE_TAGS_FROM=ec2_instance
#EOF

curl -o ecs-anywhere-install.sh https://amazon-ecs-agent.s3.amazonaws.com/ecs-anywhere-install-latest.sh
sudo bash ecs-anywhere-install.sh \
  --region $AWS_REGION \
  --cluster "${cluster_name}" \
  --activation-id "${ssm_activation_id}" \
  --activation-code "${ssm_activation_code}"

# Extra for Consul & Envoy
sudo mkdir -p /opt/vespa/var
sudo mkdir -p /etc/consul/config
sudo mkdir -p /etc/envoy

################################################
### Consul and Envoy Config (Will Remove) ######
################################################

# Write the envoy_bootstrap.json file
cat <<EOF > /etc/envoy/envoy_bootstrap.json
{
  "node": {
    "id": "envoy-sidecar",
    "cluster": "ecs-anywhere-services"
  },
  "dynamic_resources": {
    "lds_config": {
      "api_config_source": {
        "api_type": "GRPC",
        "transport_api_version": "V3",
        "grpc_services": [
          {
            "envoy_grpc": {
              "cluster_name": "xds_cluster"
            }
          }
        ]
      }
    },
    "cds_config": {
      "api_config_source": {
        "api_type": "GRPC",
        "transport_api_version": "V3",
        "grpc_services": [
          {
            "envoy_grpc": {
              "cluster_name": "xds_cluster"
            }
          }
        ]
      }
    },
    "ads_config": {
      "api_type": "GRPC",
      "transport_api_version": "V3",
      "grpc_services": [
        {
          "envoy_grpc": {
            "cluster_name": "xds_cluster"
          }
        }
      ]
    }
  },
  "static_resources": {
    "clusters": [
      {
        "name": "xds_cluster",
        "type": "STRICT_DNS",
        "connect_timeout": "5s",
        "dns_lookup_family": "V4_ONLY",
        "lb_policy": "ROUND_ROBIN",
        "load_assignment": {
          "cluster_name": "xds_cluster",
          "endpoints": [
            {
              "lb_endpoints": [
                {
                  "endpoint": {
                    "address": {
                      "socket_address": {
                        "address": "${consul_server_ip}",
                        "port_value": 8502
                      }
                    }
                  }
                }
              ]
            }
          ]
        }
      }
    ]
  },
  "admin": {
    "access_log_path": "/dev/null",
    "address": {
      "socket_address": {
        "address": "127.0.0.1",
        "port_value": 19000
      }
    }
  }
}
EOF

