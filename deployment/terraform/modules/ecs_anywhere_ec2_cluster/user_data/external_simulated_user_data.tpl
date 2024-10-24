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



