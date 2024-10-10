#!/bin/bash

# NOTE: server_ip, ip_address, is_client & is_server are all passed in as user_data variables within the Terraform module

work_dir="/opt/danswer"

echo "Preparing to install Nomad, Vault & Consul agents (server and/or client) on instance"
sudo mkdir -p $work_dir/{tmp,repo}
sudo chown -R nobody:nobody $work_dir/{tmp,repo}
sudo chmod -R 755 $work_dir/{tmp,repo}

sudo yum install -y git

cd /opt/danswer
#sudo git clone https://github.com/gmsharpe/danswer.git .
sudo git clone -b gms/infrastructure https://github.com/gmsharpe/danswer.git repo

# Copy setup scripts
sudo cp -r $work_dir/repo/deployment/nomad/terraform/ec2_cluster_deployment/modules/nomad_ec2_cluster/scripts/* /opt/danswer/
sudo cp -r $work_dir/repo/deployment/nomad/terraform/ec2_cluster_deployment/modules/nomad_ec2_cluster/shared_configurations/* /opt/danswer

# make scripts executable
sudo find $work_dir -type f -name "*.sh" -exec chmod +x {} \; #/{vault,nomad,consul,scripts}

# write the configuration for Consul, Vault & Nomad (provided as variables in the Terraform module)

# "Consul agent config" # todo - distinguish between server and clients?
cat <<EOF | sudo tee $work_dir/tmp/consul.hcl > /dev/null
${consul_config}
EOF

consul_config_override_file="$work_dir/tmp/consul.hcl"

# "Vault agent 'server' config"
cat <<EOF | sudo tee $work_dir//tmp/vault_server.hcl > /dev/null
${vault_server_config}
EOF

vault_server_config_override_file="$work_dir/tmp/vault_server.hcl"

# "Vault agent 'client' config"
cat <<EOF | sudo tee $work_dir//tmp/vault_client.hcl > /dev/null
${vault_client_config}
EOF

vault_client_config_override_file="$work_dir/tmp/vault_client.hcl"

# "Nomad agent 'server' config"
cat <<EOF | sudo tee $work_dir/tmp/nomad_server.hcl > /dev/null
${nomad_server_config}
EOF

nomad_server_config_override_file="$work_dir/tmp/nomad_server.hcl"

# "Nomad agent 'server' and 'client' config"
cat <<EOF | sudo tee $work_dir/tmp/nomad_server_and_client.hcl > /dev/null
${nomad_server_and_client_config}
EOF

nomad_server_and_client_config_override_file="$work_dir/tmp/nomad_server_and_client.hcl"

# "Use custom Nomad agent 'client' config"
cat <<EOF | sudo tee $work_dir/tmp/nomad_client.hcl > /dev/null
${nomad_client_config}
EOF

nomad_client_config_override_file="$work_dir/tmp/nomad_client.hcl"

# everything below should be moved to 'setup_agents_on_instance.sh' script
sudo WORK_DIR=$work_dir \
  install_consul=true install_vault=true install_nomad=true  \
  consul_override=${consul_override} vault_override=${vault_override} nomad_override=${nomad_override} \
  consul_config_override_file=$consul_config_override_file \
  vault_server_config_file=$vault_server_config_override_file \
  vault_client_config_file=$vault_client_config_override_file \
  nomad_server_and_config_file=$nomad_server_config_override_file \
  nomad_server_and_client_config_file=$nomad_server_and_client_config_override_file \
  nomad_client_config_file=$nomad_client_config_override_file \
  ./setup_agents_on_instance.sh -instance_ip ${ip_address} -server_ip ${server_ip} -is_server ${is_server} -is_client ${is_client}

# Execute 'setup_nomad.sh' script
#sudo VAULT_TOKEN=$VAULT_TOKEN $work_dir/scripts/setup_nomad.sh $PRIVATE_IP $SERVER_IP $is_server

# Execute 'create_volumes.sh' script
#sudo VAULT_TOKEN=$VAULT_TOKEN $work_dir/scripts/create_volumes.sh $SERVER_IP

# Execute 'post_install_setup.sh' script




