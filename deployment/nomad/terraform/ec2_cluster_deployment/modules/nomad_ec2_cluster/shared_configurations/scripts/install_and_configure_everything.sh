#!/bin/bash

# This script is based loosely on the steps taken to install and configure Consul, Vault and Nomad from Hashicorp's
# guides-configuration repo:
#
#   * https://github.com/hashicorp/nomad-guides/blob/master/operations/provision-nomad/dev/vagrant-local/Vagrantfile
#
#

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

# Nomad variables
nomad_host_port=$${NOMAD_HOST_PORT:-4646}
nomad_version=$${NOMAD_VERSION:-"1.8.4"}
# todo - should this be changed to something like 'nomad' in production?
nomad_group="root"
nomad_user="root"

cluster_name=${cluster_name:-"nomad-cluster"}
work_dir=${work_dir:-~/tmp/nomad}
is_server=${is_server:-false}

sudo yum update -y
sudo yum install -y yum-utils shadow-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo

echo "Preparing to install Nomad, Vault & Consul agents (server and/or client) on instance"
sudo mkdir -p $work_dir
sudo chown -R nobody:nobody $work_dir
sudo chmod -R 755 $work_dir

sudo yum install -y git

cd $work_dir

# make scripts executable
sudo chmod +x $work_dir/shared_configurations/*.sh
sudo find $work_dir/shared_configurations/{vault,nomad,consul,scripts} -type f -name "*.sh" -exec chmod +x {} \;

# Install and configure Consul if required
if [ ${install_consul} == true ]; then

  echo "Installing Consul"

  cd $work_dir/shared_configurations/

  sudo ./scripts/create_user.sh $consul_user $consul_group $consul_home $consul_comment

  sudo VERSION=$consul_version USER=$consul_user GROUP=$consul_group ./consul/scripts/install_consul.sh

cat <<EOF | sudo tee /tmp/consul_config.hcl > /dev/null
${consul_config}
EOF

  sudo DO_OVERRIDE_CONFIG=${consul_override} ./consul/scripts/configure_consul_agent.sh /tmp/consul_config.hcl

  sudo ./consul/scripts/install_consul_systemd.sh

fi

# Execute 'setup_vault.sh' script
if [ ${install_vault} == true ]; then

  echo "Installing Vault"

  # Steps loosely modeled after
  #   https://github.com/hashicorp/vault-guides/blob/master/operations/provision-vault/templates/install-vault-systemd.sh.tpl
  #   https://github.com/hashicorp/vault-guides/blob/master/operations/provision-vault/templates/quick-start-vault-systemd.sh.tpl

  cd $work_dir/shared_configurations/

  sudo ./scripts/create_user.sh $vault_user $vault_group $vault_home $vault_comment

  sudo VERSION=$vault_version URL=$vault_ent_url USER=$vault_user GROUP=$vault_group ./vault/scripts/install_vault.sh

  # Write the multiline strings to temporary files
cat <<EOF | sudo tee /tmp/vault_server_config.hcl > /dev/null
${vault_server_config}
EOF

cat <<EOF | sudo tee /tmp/vault_client_config.hcl > /dev/null
${vault_client_config}
EOF

  # Pass the file paths as arguments to the script
  sudo DO_OVERRIDE_CONFIG=${vault_override} is_server=$is_server cluster_name=$cluster_name \
    ./vault/scripts/configure_vault_agent.sh /tmp/vault_server_config.hcl /tmp/vault_client_config.hcl

  # Install Vault as a systemd service and start it
  sudo ./vault/scripts/install_vault_systemd.sh

  # Install Vault as a systemd service and start it
  sudo is_server=$is_server ./vault/scripts/initialize_vault.sh
fi

# Execute 'setup_nomad.sh' script

# todo - add logic to run install and configure scripts for Nomad
