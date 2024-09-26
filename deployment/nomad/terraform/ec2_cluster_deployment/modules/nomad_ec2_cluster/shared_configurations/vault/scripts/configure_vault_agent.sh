#!/bin/bash

echo "Running configure_vault_agent.sh"

vault_server_config_temp_file=$1
vault_client_config_temp_file=$2

# Use the config files
vault_server_config=$(cat "$vault_server_config_temp_file")
VAULT_CLIENT_CONFIG=$(cat "$vault_client_config_temp_file")

echo "Set variables"
DEFAULT_VAULT_CONFIG="cluster_name = \"nomad-cluster\""
VAULT_CONFIG_FILE=/etc/vault.d/vault.hcl
VAULT_CONFIG_OVERRIDE_FILE=/etc/vault.d/z-override.hcl
VAULT_PROFILE_SCRIPT=/etc/profile.d/vault.sh

DO_OVERRIDE_CONFIG=${DO_OVERRIDE_CONFIG:-false}
IS_SERVER=${IS_SERVER:-true}
CLUSTER_NAME=${CLUSTER_NAME:-"nomad-cluster"}


if [ ${DO_OVERRIDE_CONFIG} == true ]; then
  if [ ${IS_SERVER} == true ]; then
    echo "Use custom Vault agent 'server' config"
    VAULT_CONFIG=${vault_server_config}
  else
    echo "Use custom Vault agent 'client' config"
    VAULT_CONFIG=${VAULT_CLIENT_CONFIG}
  fi
else
  echo "Use default Vault agent config"
  VAULT_CONFIG=${DEFAULT_VAULT_CONFIG}
fi

# todo - check if necessary?
echo "Update Vault configuration file permissions"
sudo chown vault:vault $VAULT_CONFIG_FILE

if [ ${DO_OVERRIDE_CONFIG} == true ]; then

  echo "Add custom Vault server override config"
  cat <<CONFIG | sudo tee $VAULT_CONFIG_FILE
${VAULT_CONFIG}
CONFIG

  echo "If Vault config is overridden, don't start Vault in -dev mode"
  echo '' | sudo tee /etc/vault.d/vault.conf
fi
