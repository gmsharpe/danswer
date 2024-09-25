#!/bin/bash

echo "Running configure_vault_agent.sh"

echo "Set variables"
VAULT_CONFIG_FILE=/etc/vault.d/default.hcl
VAULT_CONFIG_OVERRIDE_FILE=/etc/vault.d/z-override.hcl
VAULT_PROFILE_SCRIPT=/etc/profile.d/vault.sh

VAULT_OVERRIDE=${VAULT_OVERRIDE:-false}
IS_SERVER=${IS_SERVER:-true}
CLUSTER_NAME=${CLUSTER_NAME:-"nomad-cluster"}

echo "Configure 'default.hcl' file"
cat <<CONFIG | sudo tee $VAULT_CONFIG_FILE
cluster_name = "${CLUSTER_NAME}"
CONFIG

echo "Update Vault configuration file permissions"
sudo chown vault:vault $VAULT_CONFIG_FILE

if [ ${VAULT_OVERRIDE} == true ] || [ ${VAULT_OVERRIDE} == 1 ]; then
  if [ "$IS_SERVER" == "true" ]; then
    echo "Add custom Vault server override config"
    cat <<CONFIG | sudo tee $VAULT_CONFIG_OVERRIDE_FILE
${VAULT_SERVER_CONFIG}
CONFIG
  else
    echo "Add custom Vault server override config"
    cat <<CONFIG | sudo tee $VAULT_CONFIG_OVERRIDE_FILE
${VAULT_CLIENT_CONFIG}
CONFIG
  fi

  echo "Update Vault configuration override file permissions"
  sudo chown vault:vault $VAULT_CONFIG_OVERRIDE_FILE

  echo "If Vault config is overridden, don't start Vault in -dev mode"
  echo '' | sudo tee /etc/vault.d/vault.conf
fi
