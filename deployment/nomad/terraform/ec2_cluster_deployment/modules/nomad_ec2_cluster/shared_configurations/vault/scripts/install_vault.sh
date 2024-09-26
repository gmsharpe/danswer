#!/bin/bash
#set -x

vault_version=${VERSION:-"1.17.5"}
vault_zip=vault_${vault_version}_linux_amd64.zip
vault_url=${URL:-https://releases.hashicorp.com/vault/${vault_version}/${vault_zip}}
vault_dir=/usr/local/bin
vault_path=${vault_dir}/vault
vault_config_dir=/etc/vault.d
vault_data_dir=/opt/vault/data
vault_tls_dir=/opt/vault/tls
vault_env_vars=${vault_config_dir}/vault.conf
vault_profile_script=/etc/profile.d/vault.sh

echo "Downloading Vault ${vault_version}"
[ 200 -ne $(curl --write-out %{http_code} --silent --output /tmp/${vault_zip} ${vault_url}) ] && exit 1

echo "Installing Vault"
sudo unzip -o /tmp/${vault_zip} -d ${vault_dir}
sudo chmod 0755 ${vault_path}
sudo chown ${USER}:${GROUP} ${vault_path}
echo "$(${vault_path} --version)"

echo "Configuring Vault ${vault_version}"
sudo mkdir -pm 0755 ${vault_config_dir} ${vault_data_dir} ${vault_tls_dir}

echo "Start Vault in -dev mode"
sudo tee ${vault_env_vars} > /dev/null <<ENVVARS
FLAGS=-dev -dev-ha -dev-transactional -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200
ENVVARS

echo "Update directory permissions"
sudo chown -R ${USER}:${GROUP} ${vault_config_dir} ${vault_data_dir} ${vault_tls_dir}
sudo chmod -R 0644 ${vault_config_dir}/*

echo "Set Vault profile script"
sudo tee ${vault_profile_script} > /dev/null <<PROFILE
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
PROFILE

echo "Granting mlock syscall to vault binary"
sudo setcap cap_ipc_lock=+ep ${vault_path}