#!/bin/bash


echo -e "\nRunning install_vault.sh"
echo "# ====================================="
echo "#        Installing Vault"
echo -e "# =====================================\n"

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

vault_user=${VAULT_USER:-"vault"}
vault_group=${VAULT_GROUP:-"vault"}


sudo mkdir -pm 0755 ${vault_config_dir} ${vault_data_dir} ${vault_tls_dir}

echo "Downloading Vault ${vault_version} from ${vault_url}"
[ 200 -ne $(curl --write-out %{http_code} --silent --output /tmp/${vault_zip} ${vault_url}) ] && exit 1

sudo unzip -o /tmp/${vault_zip} -d ${vault_dir}
sudo chmod 0755 ${vault_path}
sudo chown ${vault_user}:${group} ${vault_path}
echo "The Vault 'version' installed is:  $(${vault_path} --version)"

# Update directory permissions
sudo chown -R ${vault_user}:${group} ${vault_config_dir} ${vault_data_dir} ${vault_tls_dir}
sudo chmod -R 0640 ${vault_config_dir}

echo "Granting mlock syscall to vault binary"
# todo check if necessary here or if it should be conditionally set  based on environment

sudo setcap cap_ipc_lock=+ep ${vault_path}