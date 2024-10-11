#!/bin/bash

echo -e "\nRunning configure_vault_agent.sh"
echo "# ====================================="
echo "# ====     Configure Vault Agent   ===="
echo -e "# =====================================\n"

vault_server_config_temp_file=$1
vault_client_config_temp_file=$2

# Use the config files
vault_server_config=$(cat "$vault_server_config_temp_file")
vault_client_config=$(cat "$vault_client_config_temp_file")

# setting defaults
default_vault_config="cluster_name = \"nomad-cluster\""
vault_config_file=/etc/vault.d/vault.hcl
# todo - create this?
vault_profile_script=/etc/profile.d/vault.sh

vault_config_dir=/etc/vault.d
vault_env_vars=${vault_config_dir}/vault.conf

OVERRIDE_VAULT_ENABLED=${OVERRIDE_VAULT_ENABLED:-false}
IS_SERVER=${IS_SERVER:-true}
CLUSTER_NAME=${CLUSTER_NAME:-"nomad-cluster"}
vault_user=${VAULT_USER:-"vault"}
vault_group=${VAULT_GROUP:-"vault"}


echo "OVERRIDE_VAULT_ENABLED is set to ${OVERRIDE_VAULT_ENABLED}"
echo "IS_SERVER is set to ${IS_SERVER}"
echo "CLUSTER_NAME is set to ${CLUSTER_NAME}"
echo "vault_user is set to ${vault_user}"
echo "vault_group is set to ${vault_group}"

if [ "${OVERRIDE_VAULT_ENABLED}" = true ]; then
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

if [ "${OVERRIDE_VAULT_ENABLED}" = true ]; then

  echo "Add custom Vault server override config"
  cat <<CONFIG | sudo tee $vault_config_file > /dev/null
${vault_config}
CONFIG

  echo "If Vault config is overridden, don't start Vault in -dev mode"
  echo '' | sudo tee /etc/vault.d/vault.conf
fi

sudo chown -R ${vault_user}:${vault_group} ${vault_config_dir}
sudo chmod -R 0640 ${vault_config_dir}

ls -lh /etc/vault.d

echo