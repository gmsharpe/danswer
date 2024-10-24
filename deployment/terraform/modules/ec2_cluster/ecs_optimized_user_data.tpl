#!/bin/bash
echo "Starting user data script for ECS-optimized Amazon Linux 2023..."

# Configure ECS agent to join the desired ECS cluster
echo "ECS_CLUSTER=${cluster_name}" >> /etc/ecs/ecs.config

# Restart the ECS agent to apply the new configuration
systemctl restart ecs

echo "ECS agent configured to join cluster: ${cluster_name}"