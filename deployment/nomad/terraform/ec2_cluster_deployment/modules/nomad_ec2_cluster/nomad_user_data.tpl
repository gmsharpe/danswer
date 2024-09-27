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

# Nomad variables
nomad_host_port=$${NOMAD_HOST_PORT:-4646}
nomad_version=$${NOMAD_VERSION:-"1.8.4"}
nomad_group="root"
nomad_user="root"

nomad_plugins=("docker", "raw_exec", "java")

if [ ${is_server} == true ]; then
  node_pool="primary"
else
  node_pool="secondary"
fi


sudo yum update -y
sudo yum install -y yum-utils shadow-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo

work_dir=$${work_dir:-/opt/danswer}

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
sudo cp -r $work_dir/deployment/nomad/terraform/ec2_cluster_deployment/modules/nomad_ec2_cluster/scripts /opt/danswer
sudo cp -r $work_dir/deployment/nomad/terraform/ec2_cluster_deployment/modules/nomad_ec2_cluster/shared_configurations $work_dir

# make scripts executable
sudo chmod +x $work_dir/scripts/*.sh
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
  sudo DO_OVERRIDE_CONFIG=${vault_override} IS_SERVER=$IS_SERVER CLUSTER_NAME=$CLUSTER_NAME \
    ./vault/scripts/configure_vault_agent.sh /tmp/vault_server_config.hcl /tmp/vault_client_config.hcl

  # Install Vault as a systemd service and start it
  sudo ./vault/scripts/install_vault_systemd.sh

  # Install Vault as a systemd service and start it
  sudo IS_SERVER=$IS_SERVER ./vault/scripts/initialize_vault.sh
fi

if [ ${install_nomad} == true ]; then
  
  # todo - should likely be running nomad as a non-root user in future iterations
  #sudo ./scripts/create_user.sh $nomad_user $nomad_group $nomad_home $nomad_comment

  sudo ./nomad/scripts/install_nomad.sh $nomad_version

  if [ ${IS_SERVER} == true ]; then
    if [ ${AND_CLIENT} == true ]; then
      echo "Use custom Nomad agent 'server' config"
      cat <<EOF | sudo tee /tmp/nomad.hcl > /dev/null
${nomad_server_config}
EOF
    else
      echo "Use custom Nomad agent 'server' and 'client' config"
      cat <<EOF | sudo tee /tmp/nomad.hcl > /dev/null
${nomad_server_and_client_config}
EOF
  else
    echo "Use custom Nomad agent 'client' config"
    cat <<EOF | sudo tee /tmp/nomad.hcl > /dev/null
${nomad_client_config}
EOF
  fi

  sudo ./nomad/scripts/configure_plugins.sh "${nomad_plugins[@]}"

  # set variables for the configure_nomad_agent.sh script

  sudo DO_OVERRIDE_CONFIG=${nomad_override} NODE_POOL=$node_pool ./nomad/scripts/configure_nomad_agent.sh /tmp/nomad.hcl

  sudo ./nomad/scripts/install_nomad_systemd.sh

  # Execute 'setup_nomad.sh' script
  #sudo VAULT_TOKEN=$VAULT_TOKEN $work_dir/scripts/setup_nomad.sh $PRIVATE_IP $SERVER_IP $IS_SERVER

  # Execute 'create_volumes.sh' script
  #sudo VAULT_TOKEN=$VAULT_TOKEN $work_dir/scripts/create_volumes.sh $SERVER_IP

  # Execute 'post_install_setup.sh' script

fi





