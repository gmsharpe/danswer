#!/bin/bash

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/launch_container_instance.html

echo "Starting user data script for ECS-optimized Amazon Linux 2023..."

# Configure ECS agent to join the desired ECS cluster
echo "ECS_CLUSTER=${cluster_name}" >> /etc/ecs/ecs.config

sudo systemctl start ecs
sudo systemctl enable ecs

echo "ECS agent configured to join cluster: ${cluster_name}"