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
sudo mkdir -p /etc/consul/data
sudo mkdir -p /etc/consul/config
sudo mkdir -p /etc/envoy

################################################
### Consul and Envoy Config (Will Remove) ######
################################################

# Write the envoy_bootstrap.json file
cat <<EOF > /etc/envoy/envoy_bootstrap.json
{
  "name": "envoy",
  "image": "envoyproxy/envoy:v1.18.3",
  "cpu": 256,
  "memory": 512,
  "essential": true,
  "portMappings": [
    {
      "containerPort": 19000,
      "hostPort": 19000,
      "protocol": "tcp"
    }
  ],
  "environment": [
    {
      "name": "CONSUL_HTTP_ADDR",
      "value": "http://${consul_server_ip}:8500"
    }
  ],
  "command": [
    "envoy",
    "-c",
    "/etc/envoy/envoy_bootstrap.json"
  ],
  "mountPoints": [
    {
      "sourceVolume": "envoy-config",
      "containerPath": "/etc/envoy"
    }
  ],
  "logConfiguration": {
    "logDriver": "awslogs",
    "options": {
      "awslogs-group": "/ecs/hybrid-cluster",
      "awslogs-region": "${aws_region}",
      "awslogs-stream-prefix": "envoy"
    }
  }
}
EOF

