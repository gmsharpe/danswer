#!/bin/bash

### REMOVE after switching to using the shared_configurations scripts entirely
consul_install=$(echo "$${CONSUL_INSTALL:-true}" | tr '[:upper:]' '[:lower:]')
consul_install=$(if [[ "$consul_install" == "true" || "$consul_install" == "1" ]]; then echo true; else echo false; fi)
consul_host_port=$${CONSUL_HOST_PORT:-8500}
consul_version=$${CONSUL_VERSION:-"1.19.2"}
consul_ent_url=$${CONSUL_ENT_URL}
consul_group="consul"
consul_user="consul"
consul_comment="Consul"
consul_home="/opt/consul"

# Vault variables
vault_install=$(echo "$${VAULT_INSTALL:-true}" | tr '[:upper:]' '[:lower:]')
vault_install=$(if [[ "$vault_install" == "true" || "$vault_install" == "1" ]]; then echo true; else echo false; fi)
vault_host_port=$${VAULT_HOST_PORT:-8200}
vault_version=$${VAULT_VERSION:-"1.17.5"}
vault_ent_url=$${VAULT_ENT_URL}
vault_group="vault"
vault_user="vault"
vault_comment="Vault"
vault_home="/opt/vault"
VAULT_PROFILE_SCRIPT=/etc/profile.d/vault.sh

# Nomad variables
nomad_host_port=$${NOMAD_HOST_PORT:-4646}
nomad_version=$${NOMAD_VERSION:-"1.8.4"}
nomad_ent_url=$${NOMAD_ENT_URL}
nomad_group="root"
nomad_user="root"

# todo - default.hcl is not created, yet
CONSUL_CONFIG_DEFAULT_FILE=/etc/consul.d/default.hcl
CONSUL_CONFIG_OVERRIDE_FILE=/etc/consul.d/z-override.hcl
# this is where default settings are currently set
CONSUL_CONFIG_DIR=/etc/consul.d
CONSUL_ENV_VARS=$CONSUL_CONFIG_DIR/consul.conf

VAULT_CONFIG_FILE=/etc/vault.d/default.hcl
VAULT_CONFIG_OVERRIDE_FILE=/etc/vault.d/z-override.hcl

############################################## REMOVE ABOVE

#if [ $RUN_USER_DATA_SCRIPT == true ]; then
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

WORK_DIR=$${WORK_DIR:-/opt/danswer}

# Determine if this instance should include the server configuration
if [ ${count} -eq 0 ]; then
  IS_SERVER="true"
else
  IS_SERVER="false"
fi

echo "IS_SERVER: $IS_SERVER"

echo "Preparing to install Danswer"
sudo mkdir -p /opt/danswer && \
  sudo chown -R nobody:nobody /opt/danswer && \
  sudo chmod -R 755 /opt/danswer

sudo yum install -y git && \
  cd /opt/danswer && \
  #sudo git clone https://github.com/gmsharpe/danswer.git .
  sudo git clone -b gms/infrastructure https://github.com/gmsharpe/danswer.git .

# Copy setup scripts
sudo cp -r $WORK_DIR/deployment/nomad/terraform/ec2_cluster_deployment/modules/nomad_ec2_cluster/scripts /opt/danswer
sudo cp -r $WORK_DIR/deployment/nomad/terraform/ec2_cluster_deployment/modules/nomad_ec2_cluster/shared_configurations $WORK_DIR

# make scripts executable
sudo chmod +x $WORK_DIR/scripts/*.sh
sudo find $WORK_DIR/shared_configurations/{vault,nomad,consul,scripts} -type f -name "*.sh" -exec chmod +x {} \;

# Install and configure Consul if required
if [ $INSTALL_CONSUL == true ]; then
  #sudo $WORK_DIR/scripts/setup_consul.sh $PRIVATE_IP $SERVER_IP $IS_SERVER
  cd $WORK_DIR/shared_configurations/
  sudo USER=$consul_user GROUP=$consul_group \
    COMMENT=$consul_comment HOME=$consul_home \
    ./scripts/create_user.sh

    sudo VERSION=$consul_version sudo USER=$consul_user \
      GROUP=$consul_group ./consul/scripts/install_consul.sh

    if [ ${consul_override} == true ] || [ ${consul_override} == 1 ]; then
      echo "Add custom Consul client override config"
      cat <<CONFIG | sudo tee $CONSUL_CONFIG_OVERRIDE_FILE
${consul_config}
CONFIG

      echo "Update Consul configuration override file permissions"
      sudo chown consul:consul $CONSUL_CONFIG_OVERRIDE_FILE
    else
        # If CONSUL_OVERRIDE_CONFIG is not set, run Consul in -dev mode
        echo "CONSUL_OVERRIDE_CONFIG is not set. Starting Consul in -dev mode."

        sudo tee $${CONSUL_ENV_VARS} > /dev/null <<ENVVARS
FLAGS=-dev -ui -client 0.0.0.0
CONSUL_HTTP_ADDR=http://127.0.0.1:8500
ENVVARS

    fi

  sudo ./consul/init/systemd/install_consul_systemd.sh

fi

# Execute 'setup_vault.sh' script
if [ $INSTALL_VAULT == true ]; then
  echo "Installing Vault"
  #sudo $WORK_DIR/scripts/setup_vault.sh $PRIVATE_IP $SERVER_IP $IS_SERVER

  # Steps loosely modeled after
  #   https://github.com/hashicorp/vault-guides/blob/master/operations/provision-vault/templates/install-vault-systemd.sh.tpl
  #   https://github.com/hashicorp/vault-guides/blob/master/operations/provision-vault/templates/quick-start-vault-systemd.sh.tpl

  cd $WORK_DIR/shared_configurations/
  sudo USER=$vault_user GROUP=$vault_group \
    COMMENT=$vault_comment HOME=$vault_home \
    ./scripts/create_user.sh

  sudo VERSION=$vault_version URL=$vault_ent_url \
    USER=$vault_user GROUP=$vault_group \
    ./vault/scripts/install_vault.sh

  echo "Set variables"
  VAULT_CONFIG_FILE=/etc/vault.d/default.hcl
  VAULT_CONFIG_OVERRIDE_FILE=/etc/vault.d/z-override.hcl

  echo "Configure 'default.hcl' file"
  cat <<CONFIG | sudo tee $VAULT_CONFIG_FILE
  cluster_name = "${name}"
CONFIG

  echo "Update Vault configuration file permissions"
  sudo chown vault:vault $VAULT_CONFIG_FILE

  if [ ${vault_override} == true ] || [ ${vault_override} == 1 ]; then
    if [ "$IS_SERVER" == "true" ]; then
      echo "Add custom Vault server override config"
      cat <<CONFIG | sudo tee $VAULT_CONFIG_OVERRIDE_FILE
${vault_server_config}
CONFIG
    else
      echo "Add custom Vault server override config"
      cat <<CONFIG | sudo tee $VAULT_CONFIG_OVERRIDE_FILE
${vault_client_config}
CONFIG
    fi

    echo "Update Vault configuration override file permissions"
    sudo chown vault:vault $VAULT_CONFIG_OVERRIDE_FILE

    echo "If Vault config is overridden, don't start Vault in -dev mode"
    echo '' | sudo tee /etc/vault.d/vault.conf
  fi

  # Install Vault as a systemd service and start it
  sudo ./vault/scripts/install_vault_systemd.sh

  # unseal vault if not in dev mode
  if [ "$IS_SERVER" == "true" ]; then
      # if there is more than one 'server', this configuration would need to be adjusted to account for that by
      #    1st checking if the server is the designated leader (or first configured server) and then unsealing
      #    2nd checking if the server is a follower and then joining the leader (or first configured server) and then unsealing

      # backup the vault-init-output.txt file, if present
      if [ -f /opt/vault/data/vault-init-output.txt ]; then
          sudo mv /opt/vault/data/vault-init-output.txt /opt/vault/data/vault-init-output.txt.bak
      fi

      # Set VAULT_ADDR for further operations
      # todo - should use 'https' later
      VAULT_ADDR=http://127.0.0.1:8200

      # Initialize Vault with multiple key shares and threshold for better security
      echo "Initialize Vault"
      sudo -u vault env VAULT_ADDR="$VAULT_ADDR" vault operator init -key-shares=1 -key-threshold=1 | sudo tee /opt/vault/data/vault-init-output.txt > /dev/null

      # Extract root token and unseal keys
      root_token=$(grep 'Initial Root Token' /opt/vault/data/vault-init-output.txt | awk '{print $NF}')
      unseal_key=$(grep 'Unseal Key ' /opt/vault/data/vault-init-output.txt | awk '{print $NF}')

      # Save unseal keys and root token securely
      # if multiple unseal keys are generated, this file should be adjusted accordingly
      sudo tee /opt/vault/data/keys.txt > /dev/null <<EOT
vault_root_token=$root_token
vault_unseal_keys=$unseal_key
EOT
      sudo chmod 600 /opt/vault/data/keys.txt

      # Set VAULT_TOKEN for further operations
      VAULT_TOKEN="$root_token"

      # todo - should adjust for tls and other security measures later
      echo "Set Vault profile script"
      sudo tee $${VAULT_PROFILE_SCRIPT} > /dev/null <<PROFILE
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$VAULT_TOKEN
PROFILE

      echo "Unsealing Vault"
      sudo -u vault VAULT_ADDR=$VAULT_ADDR vault operator unseal "$unseal_key"

      # Enable KV secrets engine at 'secret' path
      echo "Enable KV secrets engine with path = 'secret'"
      sudo -u vault VAULT_ADDR=$VAULT_ADDR VAULT_TOKEN=$VAULT_TOKEN vault secrets enable -path=secret kv-v2

      echo "Vault is initialized and unsealed on the leader node."
  fi
fi

# Execute 'setup_nomad.sh' script
sudo $WORK_DIR/scripts/setup_nomad.sh $PRIVATE_IP $SERVER_IP $IS_SERVER

# Execute 'create_volumes.sh' script
sudo $WORK_DIR/scripts/create_volumes.sh $SERVER_IP
