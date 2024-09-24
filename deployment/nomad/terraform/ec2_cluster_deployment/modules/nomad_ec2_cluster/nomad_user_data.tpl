#!/bin/bash

RUN_USER_DATA_SCRIPT=${run_user_data_script}

if [ "$RUN_USER_DATA_SCRIPT" == "true" ]; then
  echo "Running user data script"
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
    #sudo git clone https://github.com/gmsharpe/danswer.git .
    sudo git clone -b gms/infrastructure https://github.com/gmsharpe/danswer.git .

  # Copy setup scripts
  sudo cp -r /opt/danswer/deployment/nomad/terraform/ec2_cluster_deployment/modules/nomad_ec2_cluster/scripts /opt/danswer
  sudo cp -r /opt/danswer/deployment/nomad/terraform/ec2_cluster_deployment/modules/nomad_ec2_cluster/shared_configurations /opt/danswer

  # make scripts executable
  sudo chmod +x /opt/danswer/scripts/*.sh

  # Execute 'setup_vault.sh' script
  if [ "$INSTALL_VAULT" == "true" ]; then
    #sudo /opt/danswer/scripts/setup_vault.sh $PRIVATE_IP $SERVER_IP $IS_SERVER

    # Steps originally outlined by
    #   https://github.com/hashicorp/vault-guides/blob/master/operations/provision-vault/templates/install-vault-systemd.sh.tpl

    cd /opt/danswer/shared_configurations/
    sudo USER=$vault_user GROUP=$vault_group \
      COMMENT=$vault_comment HOME=$vault_home \
      ./scripts/create_user.sh

    sudo VERSION=$vault_version URL=$vault_ent_url \
      USER=$vault_user GROUP=$vault_group \
      ./vault/scripts/install_vault.sh

    sudo ./vault/scripts/install-vault-systemd.sh

    echo "Set variables"
    VAULT_CONFIG_FILE=/etc/vault.d/default.hcl
    VAULT_CONFIG_OVERRIDE_FILE=/etc/vault.d/z-override.hcl

    echo "Minimal configuration for Vault"
    cat <<CONFIG | sudo tee $VAULT_CONFIG_FILE
cluster_name = "${name}"
CONFIG

    echo "Update Vault configuration file permissions"
    sudo chown vault:vault $VAULT_CONFIG_FILE

    if [ ${vault_override} == true ] || [ ${vault_override} == 1 ]; then
      echo "Add custom Vault server override config"
      cat <<CONFIG | sudo tee $VAULT_CONFIG_OVERRIDE_FILE
${vault_config}
CONFIG

      echo "Update Vault configuration override file permissions"
      sudo chown vault:vault $VAULT_CONFIG_OVERRIDE_FILE

      echo "If Vault config is overridden, don't start Vault in -dev mode"
      echo '' | sudo tee /etc/vault.d/vault.conf
    fi

    echo "Restart Vault"
    sudo systemctl restart vault

  fi

  # Execute 'setup_nomad.sh' script
  sudo /opt/danswer/scripts/setup_nomad.sh $PRIVATE_IP $SERVER_IP $IS_SERVER

  # Execute 'create_volumes.sh' script
  sudo /opt/danswer/scripts/create_volumes.sh $SERVER_IP


  ### CONSUL ###

  # Install and configure Consul if required
  if [ "$INSTALL_CONSUL" == "true" ]; then
    sudo /opt/danswer/scripts/setup_consul.sh $PRIVATE_IP $SERVER_IP $IS_SERVER
  fi
fi
