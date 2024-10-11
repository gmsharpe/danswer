#!/bin/bash

# Based in part on https://github.com/hashicorp/guides-configuration/blob/master/nomad/scripts/install-nomad.sh

echo -e "\nRunning install_nomad.sh"
echo "# ====================================="
echo "#        Installing Nomad"
echo -e "# =====================================\n"


nomad_user="${NOMAD_USER:-root}"
nomad_group="${NOMAD_GROUP:-root}"
VERSION="${1:-1.8.4}" # most recent as of 09/27/24

nomad_version=${VERSION}
nomad_zip=nomad_${nomad_version}_linux_amd64.zip
nomad_url=${URL:-https://releases.hashicorp.com/nomad/${nomad_version}/${nomad_zip}}
nomad_dir=/usr/local/bin
nomad_path=${nomad_dir}/nomad
nomad_config_dir=/etc/nomad.d
nomad_data_dir=/opt/nomad/data
nomad_tls_dir=/opt/nomad/tls
nomad_env_vars=${nomad_config_dir}/nomad.conf
nomad_profile_script=/etc/profile.d/nomad.sh

echo "Downloading Nomad ${nomad_version} from ${nomad_url}"
[ 200 -ne $(curl --write-out %{http_code} --silent --output /tmp/${nomad_zip} ${nomad_url}) ] && exit 1

sudo mkdir -pm 0755 ${nomad_config_dir} ${nomad_data_dir} ${nomad_tls_dir}

sudo unzip -o /tmp/${nomad_zip} -d ${nomad_dir}
sudo chmod 0755 ${nomad_path}
sudo chown ${nomad_user}:${nomad_GROUP} ${nomad_path}
echo "$(${nomad_path} --version)"

sudo chown -R ${nomad_user}:${nomad_GROUP} ${nomad_config_dir} ${nomad_data_dir} ${nomad_tls_dir}
sudo chmod -R 0640 ${nomad_config_dir}

echo
