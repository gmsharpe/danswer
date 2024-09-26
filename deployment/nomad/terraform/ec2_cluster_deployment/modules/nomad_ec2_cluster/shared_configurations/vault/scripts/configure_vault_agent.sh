#!/bin/bash

echo "Running configure_vault_agent.sh"

VAULT_SERVER_CONFIG_TEMP_FILE=$1
VAULT_CLIENT_CONFIG_TEMP_FILE=$2

# Use the config files
VAULT_SERVER_CONFIG=$(cat "$VAULT_SERVER_CONFIG_TEMP_FILE")
VAULT_CLIENT_CONFIG=$(cat "$VAULT_CLIENT_CONFIG_TEMP_FILE")

echo "Set variables"
DEFAULT_VAULT_CONFIG="cluster_name = \"nomad-cluster\""
VAULT_CONFIG_FILE=/etc/vault.d/vault.hcl
VAULT_CONFIG_OVERRIDE_FILE=/etc/vault.d/z-override.hcl
VAULT_PROFILE_SCRIPT=/etc/profile.d/vault.sh

DO_OVERRIDE_CONFIG=${DO_OVERRIDE_CONFIG:-false}
IS_SERVER=${IS_SERVER:-true}
CLUSTER_NAME=${CLUSTER_NAME:-"nomad-cluster"}


if [ "$DO_OVERRIDE_CONFIG" == "true" ] || [ "$DO_OVERRIDE_CONFIG" == 1 ]; then
  if [ "$IS_SERVER" == "true" ]; then
    VAULT_CONFIG=${VAULT_SERVER_CONFIG}
  else
    VAULT_CONFIG=${VAULT_CLIENT_CONFIG}
  fi
fi
else
  VAULT_CONFIG=${DEFAULT_VAULT_CONFIG}
fi

# todo - check if necessary?
echo "Update Vault configuration file permissions"
sudo chown vault:vault $VAULT_CONFIG_FILE

if [ ${DO_OVERRIDE_CONFIG} == true ] || [ ${DO_OVERRIDE_CONFIG} == 1 ]; then

  echo "Add custom Vault server override config"
  cat <<CONFIG | sudo tee $VAULT_CONFIG_FILE
${VAULT_CONFIG}
CONFIG

  echo "If Vault config is overridden, don't start Vault in -dev mode"
  echo '' | sudo tee /etc/vault.d/vault.conf
fi
