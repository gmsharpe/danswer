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
VAULT_PROFILE_SCRIPT=/etc/profile.d/vault.sh

DO_OVERRIDE_CONFIG=${DO_OVERRIDE_CONFIG:-false}
IS_SERVER=${IS_SERVER:-true}
CLUSTER_NAME=${CLUSTER_NAME:-"nomad-cluster"}


if [ ${DO_OVERRIDE_CONFIG} == true ]; then
  if [ ${IS_SERVER} == true ]; then
    echo "Use custom Vault agent 'server' config"
    vault_config=${vault_server_config}
  else
    echo "Use custom Vault agent 'client' config"
    vault_config=${vault_client_config}
  fi
else
  echo "Use default Vault agent config"
  vault_config=${default_vault_config}
fi

if [ ${DO_OVERRIDE_CONFIG} == true ]; then

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
