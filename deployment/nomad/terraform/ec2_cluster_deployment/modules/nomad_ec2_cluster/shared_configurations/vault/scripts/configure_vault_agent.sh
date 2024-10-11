#!/bin/bash

echo -e "\nRunning configure_vault_agent.sh"
echo "# ====================================="
echo "# ====     Configure Vault Agent   ===="
echo -e "# =====================================\n"

# Function to display usage
usage() {
  echo "Usage: $0 -vault_server_config_file <vault_server_config_file_path> -vault_client_config_file <vault_client_config_file_path> -instance_ip <IP> -is_server <true|false> -is_client <true|false> -server_ip <IP> -override_vault_config_enabled <true|false>"
  exit 1
}

# Parse the remaining named arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -vault_server_config_file)
      vault_server_config_file="$2"
      shift 2
      ;;
    -vault_client_config_file)
      vault_client_config_file="$2"
      shift 2
      ;;
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
    -override_vault_config_enabled)
      override_vault_config_enabled="$2"
      shift 2
      ;;
    *)
      echo "Invalid argument: $1"
      usage
      ;;
  esac
done

# Use the config files
vault_server_config=$(cat "$vault_server_config_file")
vault_client_config=$(cat "$vault_client_config_file")

# setting defaults
default_vault_config="cluster_name = \"nomad-cluster\""
vault_config_file=/etc/vault.d/vault.hcl
# todo - create this?
vault_profile_script=/etc/profile.d/vault.sh

vault_config_dir=/etc/vault.d
vault_env_vars=${vault_config_dir}/vault.conf

override_vault_config_enabled=${override_vault_config_enabled:-false}
is_server=${is_server:-true}
cluster_name=${cluster_name:-"nomad-cluster"}
vault_user=${vault_user:-"vault"}
vault_group=${vault_group:-"vault"}


echo "override_vault_config_enabled is set to ${override_vault_config_enabled}"
echo "is_server is set to ${is_server}"
echo "cluster_name is set to ${cluster_name}"
echo "vault_user is set to ${vault_user}"
echo "vault_group is set to ${vault_group}"

if [ "${override_vault_config_enabled}" = true ]; then
  if [ "${is_server}" = true ]; then
    echo "Use custom Vault agent 'server' config"
    vault_config=${vault_server_config}
  else
    echo "Use custom Vault agent 'client' config"
    vault_config=${vault_client_config}
  fi
else
  echo "Use default Vault agent config"
  vault_config=${default_vault_config}

  echo "Start Vault in -dev mode"
  sudo tee ${vault_env_vars} > /dev/null <<ENVVARS
FLAGS=-dev -dev-ha -dev-transactional -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200
ENVVARS

fi

if [ "${override_vault_config_enabled}" = true ]; then

  echo "Add custom Vault server override config"
  cat <<CONFIG | sudo tee $vault_config_file > /dev/null
${vault_config}
CONFIG

  echo "If Vault config is overridden, don't start Vault in -dev mode"
  echo '' | sudo tee /etc/vault.d/vault.conf
fi

echo "before updating permissions (remove later)"
ls -lh /etc/vault.d

# do I need this?
sudo chown -R ${vault_user}:${vault_group} ${vault_config_dir}
sudo chmod -R 0640 ${vault_config_dir}
sudo chmod 750 ${vault_config_dir}

ls -lh /etc/vault.d

echo