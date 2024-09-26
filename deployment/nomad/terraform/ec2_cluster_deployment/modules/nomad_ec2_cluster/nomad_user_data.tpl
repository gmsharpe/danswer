#!/bin/bash

### REMOVE after switching to using the shared_configurations scripts entirely

consul_host_port=$${CONSUL_HOST_PORT:-8500} # todo - not used at the moment.use it.
consul_version=$${CONSUL_VERSION:-"1.19.2"}
consul_group="consul"
consul_user="consul"
consul_comment="Consul"
consul_home="/opt/consul"

# Vault variables
vault_host_port=$${VAULT_HOST_PORT:-8200} # todo - not used at the moment. use it.
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
nomad_group="root"
nomad_user="root"

# todo - default.hcl is not created, yet
CONSUL_CONFIG_DEFAULT_FILE=/etc/consul.d/default.hcl
CONSUL_CONFIG_OVERRIDE_FILE=/etc/consul.d/z-override.hcl
# this is where default settings are currently set
CONSUL_CONFIG_DIR=/etc/consul.d

VAULT_CONFIG_FILE=/etc/vault.d/default.hcl
VAULT_CONFIG_OVERRIDE_FILE=/etc/vault.d/z-override.hcl

############################################## REMOVE ABOVE

#if [ ${run_user_data_script} == false ]; then
#  echo "Do not run user data script"
#  exit 0
#fi

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

CLUSTER_NAME=${name}

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

  cd $WORK_DIR/shared_configurations/

  CONSUL_CONFIG=$(cat <<EOF
${consul_config}
EOF
  )

  sudo USER=$consul_user GROUP=$consul_group COMMENT=$consul_comment HOME=$consul_home ./scripts/create_user.sh

  sudo VERSION=$consul_version USER=$consul_user GROUP=$consul_group ./consul/scripts/install_consul.sh

  sudo CONSUL_OVERRIDE_CONFIG=$${CONSUL_CONFIG} DO_OVERRIDE_CONFIG=${consul_override} ./consul/scripts/configure_consul_agent.sh

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

    VAULT_SERVER_CONFIG=$(cat <<EOF
${vault_server_config}
EOF
    )

    VAULT_CLIENT_CONFIG=$(cat <<EOF
${vault_client_config}
EOF
    )

  sudo DO_OVERRIDE_CONFIG=${vault_override} IS_SERVER=$IS_SERVER CLUSTER_NAME=$CLUSTER_NAME \
    VAULT_SERVER_CONFIG=$${VAULT_SERVER_CONFIG} VAULT_CLIENT_CONFIG=$${VAULT_CLIENT_CONFIG} \
    ./vault/scripts/configure_vault_agent.sh

  # Install Vault as a systemd service and start it
  sudo ./vault/scripts/install_vault_systemd.sh

  # Install Vault as a systemd service and start it
  sudo IS_SERVER=$IS_SERVER ./vault/scripts/initialize_vault.sh
fi

# Execute 'setup_nomad.sh' script
sudo VAULT_TOKEN=$VAULT_TOKEN $WORK_DIR/scripts/setup_nomad.sh $PRIVATE_IP $SERVER_IP $IS_SERVER

# Execute 'create_volumes.sh' script
sudo VAULT_TOKEN=$VAULT_TOKEN $WORK_DIR/scripts/create_volumes.sh $SERVER_IP
