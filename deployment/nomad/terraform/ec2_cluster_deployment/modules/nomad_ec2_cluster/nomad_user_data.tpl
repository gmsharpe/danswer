#!/bin/bash

#RUN_USER_DATA_SCRIPT=${run_user_data_script}

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

# Nomad variables
nomad_host_port=$${NOMAD_HOST_PORT:-4646}
nomad_version=$${NOMAD_VERSION:-"1.8.4"}
nomad_ent_url=$${NOMAD_ENT_URL}
nomad_group="root"
nomad_user="root"

CONSUL_CONFIG_OVERRIDE_FILE=/etc/consul.d/z-override.json
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
IS_SERVER="${count == 0 ? "true" : "false"}"
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

    if [ ${consul_override} == true ] || [ ${consul_override} == 1 ]; then
      echo "Add custom Consul client override config"
      cat <<CONFIG | sudo tee $CONSUL_CONFIG_OVERRIDE_FILE
${consul_config}
CONFIG

      echo "Update Consul configuration override file permissions"
      sudo chown consul:consul $CONSUL_CONFIG_OVERRIDE_FILE
    fi

  sudo VERSION=$consul_version sudo USER=$consul_user \
    GROUP=$consul_group CONSUL_CONFIG_OVERRIDE_FILE=$CONSUL_CONFIG_OVERRIDE_FILE \
    CONSUL_OVERRIDE=${consul_override} ./consul/scripts/install_consul.sh

  sudo ./consul/scripts/install_consul_systemd.sh

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

  sudo ./vault/scripts/install_vault_systemd.sh

  echo "Set variables"
  VAULT_CONFIG_FILE=/etc/vault.d/default.hcl
  VAULT_CONFIG_OVERRIDE_FILE=/etc/vault.d/z-override.hcl

  echo "Configure Vault with Raft storage and clustering settings"
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
sudo $WORK_DIR/scripts/setup_nomad.sh $PRIVATE_IP $SERVER_IP $IS_SERVER

# Execute 'create_volumes.sh' script
sudo $WORK_DIR/scripts/create_volumes.sh $SERVER_IP

### CONSUL ###


#fi
