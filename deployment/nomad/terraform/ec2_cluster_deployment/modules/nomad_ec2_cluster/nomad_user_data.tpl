#!/bin/bash

RUN_USER_DATA_SCRIPT=${run_user_data_script}

if [ "$RUN_USER_DATA_SCRIPT" == "true" ]; then
  sudo yum update -y
  sudo yum install -y yum-utils shadow-utils
  sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo

  # Use EC2 metadata service to get the instance's private IP
  PRIVATE_IP=${private_ip} #$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
  SERVER_IP=${server_ip}

  # convert variables to uppercase for consistency
  INSTALL_CONSUL=${install_consul}
  INSTALL_DANSWER=${install_danswer}
  INSTALL_VAULT=${install_vault}

  # Determine if this instance should include the server configuration
  IS_SERVER="${count == 0 ? "true" : "false"}"

  echo "Preparing to install Danswer"
  sudo mkdir -p /opt/danswer && \
    sudo chown -R nobody:nobody /opt/danswer && \
    sudo chmod -R 755 /opt/danswer

  sudo yum install -y git && \
    cd /opt/danswer && \
    sudo git clone https://github.com/gmsharpe/danswer.git .

  # Copy nginx files
  sudo cp -r /opt/danswer/deployment/data/nginx /var/nomad/volumes/danswer

  # Copy setup scripts
  sudo cp -r /opt/danswer/deployment/terraform/nomad/ec2_cluster_deployment/scripts /opt/danswer/deployment/nomad

  # Execute 'setup_vault.sh' script
  if [ "$INSTALL_VAULT" == "true" ]; then
    sudo /opt/danswer/deployment/nomad/scripts/setup_vault.sh $PRIVATE_IP $SERVER_IP $IS_SERVER
  fi

  # Execute 'setup_nomad.sh' script
  sudo /opt/danswer/deployment/nomad/scripts/setup_nomad.sh $PRIVATE_IP $SERVER_IP $IS_SERVER

  # Execute 'create_volumes.sh' script
  sudo /opt/danswer/deployment/nomad/create_volumes.sh $SERVER_IP


  ### CONSUL ###

  # Install and configure Consul if required
  if [ "$INSTALL_CONSUL" == "true" ]; then
    sudo /opt/danswer/deployment/nomad/scripts/setup_consul.sh $PRIVATE_IP $SERVER_IP $IS_SERVER
  fi
fi
