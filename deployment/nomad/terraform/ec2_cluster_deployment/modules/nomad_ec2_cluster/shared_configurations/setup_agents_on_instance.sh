#!/bin/bash

sudo yum update -y
sudo yum install -y yum-utils shadow-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo

# Parse the named arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -instance_ip)
      instance_ip="$2"
      shift 2
      ;;
    -is_server)
      is_server="$2"
      shift 2
      ;;
    -is_client)
      is_client="$2"
      shift 2
      ;;
    -server_ip)
      server_ip="$2"
      shift 2
      ;;
    -consul_override)
      consul_override="$2"
      shift 2
      ;;
    -vault_override)
      vault_override="$2"
      shift 2
      ;;
    -nomad_override)
      nomad_override="$2"
      shift 2
      ;;
    *)
      echo "Invalid argument: $1"
      usage
      ;;
  esac
done

echo "Preparing to install Nomad, Vault & Consul agents (server and/or client) on instance"

# Consul variables
consul_host_port=${CONSUL_HOST_PORT:-8500} # todo - not used at the moment.use it.
consul_version=${CONSUL_VERSION:-"1.19.2"}
consul_group="consul"
consul_user="consul"
consul_comment="Consul"
consul_home="/opt/consul"
consul_override=${consul_override:-false}

# Vault variables
vault_host_port=${VAULT_HOST_PORT:-8200} # todo - not used at the moment. use it.
vault_version=${VAULT_VERSION:-"1.17.5"}
vault_ent_url=${VAULT_ENT_URL}
vault_group="vault"
vault_user="vault"
vault_comment="Vault"
vault_home="/opt/vault"
vault_id=${VAULT_ID:-"nomad-cluster-$(date +'%m-%d-%Y')"}
vault_override=${vault_override:-false}

# Nomad variables
nomad_host_port=${NOMAD_HOST_PORT:-4646}
nomad_version=${NOMAD_VERSION:-"1.8.4"}
# todo - should this be changed to something like 'nomad' in production?
nomad_group="root"
nomad_user="root"
nomad_override=${nomad_override:-false}

cluster_name=${CLUSTER_NAME:-"nomad-cluster"}
work_dir=${WORK_DIR:-~/tmp/nomad}
is_server=${is_server:-false}
is_client=${is_client:-false} # is BOTH server and client

nomad_plugins=("docker" "raw_exec" "java")

# todo - replace with more appropriate logic for determining node pool
if [ ${is_server} == true ]; then
  node_pool="primary"
else
  node_pool="secondary"
fi

if [ ! -d "$work_dir" ]; then
  sudo mkdir -p $work_dir
  sudo chown -R nobody:nobody $work_dir
  sudo chmod -R 755 $work_dir
fi

cd $work_dir

# make scripts executable
sudo find $work_dir -type f -name "*.sh" -exec chmod +x {} \;

# =====================================
#        Installing Consul
# =====================================

if [ "${install_consul}" = true ]; then

  cd $work_dir

  sudo ./scripts/create_user.sh $consul_user $consul_group $consul_home $consul_comment

  sudo VERSION=$consul_version USER=$consul_user GROUP=$consul_group ./consul/scripts/install_consul.sh

  consul_config_file=${consul_config_override_dir:-$work_dir/consul/config/consul.hcl}

  sudo CONSUL_OVERRIDE_ENABLED=${consul_override} ./consul/scripts/configure_consul_agent.sh $consul_config_file

  sudo ./consul/scripts/install_consul_systemd.sh

fi

# =====================================
#        Installing Vault
# =====================================

if [ "${install_vault}" = true ]; then

  # Steps loosely modeled after
  #   https://github.com/hashicorp/vault-guides/blob/master/operations/provision-vault/templates/install-vault-systemd.sh.tpl
  #   https://github.com/hashicorp/vault-guides/blob/master/operations/provision-vault/templates/quick-start-vault-systemd.sh.tpl

  cd $work_dir

  sudo ./scripts/create_user.sh $vault_user $vault_group $vault_home $vault_comment

  sudo VERSION=$vault_version URL=$vault_ent_url USER=$vault_user GROUP=$vault_group ./vault/scripts/install_vault.sh

  vault_server_config_file=${vault_server_config_override_dir:-$work_dir/vault/config/vault_server.hcl}
  vault_client_config_file=${vault_client_config_override_dir:-$work_dir/vault/config/vault_client.hcl}

  # Pass the file paths as arguments to the script
  sudo DO_OVERRIDE_CONFIG=${vault_override} is_server=$is_server cluster_name=$cluster_name \
    ./vault/scripts/configure_vault_agent.sh $vault_server_config_file $vault_client_config_file

  # Install Vault as a systemd service and start it
  sudo ./vault/scripts/install_vault_systemd.sh

  # Install Vault as a systemd service and start it
  sudo ./vault/scripts/initialize_vault.sh \
                          -vault_id $vault_id \
                          -save_keys_externally true \
                          -num_key_shares 1 \
                          -num_key_threshold 1 \
                          -is_server $is_server
fi

# =====================================
#        Installing Nomad
# =====================================
echo "install_nomad is set to ${install_nomad}"

if [ "${install_nomad}" = true ]; then

  cd $work_dir

  # todo - should likely be running nomad as a non-root user in future iterations
  #sudo ./scripts/create_user.sh $nomad_user $nomad_group $nomad_home $nomad_comment

  sudo ./nomad/scripts/install_nomad.sh $nomad_version

  sudo ./nomad/scripts/configure_plugins.sh "${nomad_plugins[@]}"

  # Determine the configuration file based on server and client roles
  if [ "${is_server}" = true ] && [ "${is_client}" = true ]; then
    # Server and client
    nomad_config_file=${nomad_server_and_client_config_file:-$work_dir/nomad/config/nomad_server_and_client.hcl}
  elif [ "${is_server}" = true ]; then
    # Server only
    nomad_config_file=${nomad_server_config_file:-$work_dir/nomad/config/nomad_server.hcl}
  else
    # Client only
    nomad_config_file=${nomad_client_config_file:-$work_dir/nomad/config/nomad_client.hcl}
  fi

  # Verify if the config file exists
  if [ ! -f "$nomad_config_file" ]; then
    echo "Error: Configuration file $nomad_config_file does not exist."
    exit 1
  fi

  sudo NOMAD_OVERRIDE_ENABLED=${nomad_override} NODE_POOL=$node_pool
    ./nomad/scripts/configure_nomad_agent.sh \
    -config_override_file $nomad_config_file \
    -instance_ip ${instance_ip} \
    -is_server ${is_server} \
    -is_client ${is_client} \
    -server_ip ${server_ip} # todo - should be passed as an array

  # get Vault Token from ssm parameter store
  vault_token=$(aws ssm get-parameter --name /${vault_id}/root-key --with-decryption --query Parameter.Value --output text)
  echo "Vault Token: $vault_token" # todo - comment this out or remove later!

  sudo ./nomad/scripts/add_vault_config.sh -vault_token $vault_token -vault_server_ip ${server_ip}

  sudo ./nomad/scripts/install_nomad_systemd.sh

fi