#!/bin/bash

# Based on - https://github.com/hashicorp/guides-configuration/blob/master/consul/scripts/install-consul.sh

echo "Running install_consul.sh"

CONSUL_VERSION=${VERSION:-"1.19.2"}
CONSUL_ZIP=consul_${CONSUL_VERSION}_linux_amd64.zip
# URL is optional, if not provided it will default to the HashiCorp releases page (can be used to provide enterprise URL)
CONSUL_URL=${URL:-https://releases.hashicorp.com/consul/${CONSUL_VERSION}/${CONSUL_ZIP}}
CONSUL_DIR=/usr/local/bin
CONSUL_PATH=${CONSUL_DIR}/consul
CONSUL_CONFIG_DIR=/etc/consul.d
CONSUL_DATA_DIR=/opt/consul/data
CONSUL_TLS_DIR=/opt/consul/tls
CONSUL_PROFILE_SCRIPT=/etc/profile.d/consul.sh

echo "Downloading Consul ${CONSUL_VERSION}"
[ 200 -ne $(curl --write-out %{http_code} --silent --output /tmp/${CONSUL_ZIP} ${CONSUL_URL}) ] && exit 1

echo "Installing Consul"
sudo unzip -o /tmp/${CONSUL_ZIP} -d ${CONSUL_DIR}
sudo chmod 0755 ${CONSUL_PATH}
sudo chown ${USER}:${GROUP} ${CONSUL_PATH}
echo "$(${CONSUL_PATH} --version)"

echo "Configuring Consul ${CONSUL_VERSION}"
sudo mkdir -pm 0755 ${CONSUL_CONFIG_DIR} ${CONSUL_DATA_DIR} ${CONSUL_TLS_DIR}

echo "Update directory permissions"
sudo chown -R ${USER}:${GROUP} ${CONSUL_CONFIG_DIR} ${CONSUL_DATA_DIR} ${CONSUL_TLS_DIR}
# updated since the original script was not working as expected
sudo find ${CONSUL_CONFIG_DIR} -type f -exec chmod 0644 {} \;

# Set Consul profile script
echo "Setting Consul profile script"
sudo tee ${CONSUL_PROFILE_SCRIPT} > /dev/null <<PROFILE
export CONSUL_HTTP_ADDR=http://127.0.0.1:8500
PROFILE

echo "Give consul user shell access for remote exec"
sudo /usr/sbin/usermod --shell /bin/bash ${USER} >/dev/null

echo "Allow consul sudo access for echo, tee, cat, sed, and systemctl"
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

echo "Complete"