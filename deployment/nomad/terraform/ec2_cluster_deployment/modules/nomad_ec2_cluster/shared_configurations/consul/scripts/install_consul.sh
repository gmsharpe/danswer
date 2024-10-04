#!/bin/bash

# Based on - https://github.com/hashicorp/guides-configuration/blob/master/consul/scripts/install-consul.sh

echo "Running install_consul.sh"
echo "# ====================================="
echo "#        Installing Consul"
echo "# ====================================="

consul_version=${VERSION:-"1.19.2"}
consul_zip=consul_${consul_version}_linux_amd64.zip
# URL is optional, if not provided it will default to the HashiCorp releases page (can be used to provide enterprise URL)
consul_url=${URL:-https://releases.hashicorp.com/consul/${consul_version}/${consul_zip}}
consul_dir=/usr/local/bin
consul_path=${consul_dir}/consul
consul_config_dir=/etc/consul.d
consul_data_dir=/opt/consul/data
consul_tls_dir=/opt/consul/tls
consul_profile_script=/etc/profile.d/consul.sh

echo "Downloading Consul ${consul_version} from ${consul_url}"
[ 200 -ne $(curl --write-out %{http_code} --silent --output /tmp/${consul_zip} ${consul_url}) ] && exit 1

sudo unzip -o /tmp/${consul_zip} -d ${consul_dir}
sudo chmod 0755 ${consul_path}
sudo chown ${USER}:${GROUP} ${consul_path}
echo "$(${consul_path} --version)"

sudo mkdir -pm 0755 ${consul_config_dir} ${consul_data_dir} ${consul_tls_dir}

sudo chown -R ${USER}:${GROUP} ${consul_config_dir} ${consul_data_dir} ${consul_tls_dir}
# updated since the original script was not working as expected
sudo find ${consul_config_dir} -type f -exec chmod 0644 {} \;

# Set Consul profile script
# todo - this should be set based on environment and likely in 'configure_consul_agent.sh'
sudo tee ${consul_profile_script} > /dev/null <<PROFILE
export CONSUL_HTTP_ADDR=http://127.0.0.1:8500
PROFILE

echo "Give consul user shell access for remote exec"
# todo - check on necessity of this
sudo /usr/sbin/usermod --shell /bin/bash ${USER} >/dev/null

# "Allow consul sudo access for echo, tee, cat, sed, and systemctl"
sudo tee /etc/sudoers.d/consul > /dev/null <<SUDOERS
consul ALL=(ALL) NOPASSWD: /usr/bin/echo, /usr/bin/tee, /usr/bin/cat, /usr/bin/sed, /usr/bin/systemctl
SUDOERS

echo "Installing dnsmasq"
sudo yum install -q -y dnsmasq

echo "Update resolv.conf"
sudo sed -i '1i nameserver 127.0.0.1\n' /etc/resolv.conf

echo "Configuring dnsmasq to forward .consul requests to consul port 8600"
sudo tee /etc/dnsmasq.d/consul > /dev/null <<DNSMASQ
server=/consul/127.0.0.1#8600
DNSMASQ

echo "Enable and restart dnsmasq"
sudo systemctl enable dnsmasq
sudo systemctl restart dnsmasq