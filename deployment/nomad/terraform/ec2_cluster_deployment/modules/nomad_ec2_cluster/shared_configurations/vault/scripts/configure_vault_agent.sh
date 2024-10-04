#!/bin/bash

echo "Running configure_vault_agent.sh"

vault_server_config_temp_file=$1
vault_client_config_temp_file=$2

# Use the config files
vault_server_config=$(cat "$vault_server_config_temp_file")
vault_client_config=$(cat "$vault_client_config_temp_file")

echo "Set variables"
default_vault_config="cluster_name = \"nomad-cluster\""
vault_config_file=/etc/vault.d/vault.hcl
# todo - create this?
vault_profile_script=/etc/profile.d/vault.sh

vault_config_dir=/etc/vault.d
vault_env_vars=${vault_config_dir}/vault.conf

DO_OVERRIDE_CONFIG=${DO_OVERRIDE_CONFIG:-false}
IS_SERVER=${IS_SERVER:-true}
CLUSTER_NAME=${CLUSTER_NAME:-"nomad-cluster"}

echo "DO_OVERRIDE_CONFIG is set to ${DO_OVERRIDE_CONFIG}"
echo "IS_SERVER is set to ${IS_SERVER}"
echo "CLUSTER_NAME is set to ${CLUSTER_NAME}"

if [ "${DO_OVERRIDE_CONFIG}" = true ]; then
  if [ "${IS_SERVER}" = true ]; then
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

if [ "${DO_OVERRIDE_CONFIG}" = true ]; then

  echo "Add custom Vault server override config"
  cat <<CONFIG | sudo tee $vault_config_file > /dev/null
${vault_config}
CONFIG

  # todo - check if necessary?
  echo "Update Vault configuration file permissions"
  sudo chown vault:vault $vault_config_file

  echo "If Vault config is overridden, don't start Vault in -dev mode"
  echo '' | sudo tee /etc/vault.d/vault.conf
fi

# todo check if necessary here or if it should be conditionally set  based on environment
echo "Granting mlock syscall to vault binary"
sudo setcap cap_ipc_lock=+ep ${vault_path}
