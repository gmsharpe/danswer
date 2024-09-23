#!/bin/bash
set -x

# This script is based loosely on the steps taken to install and configure Consul, Vault and Nomad from Hashicorp's
# guides-configuration repo:
#
#   * https://github.com/hashicorp/nomad-guides/blob/master/operations/provision-nomad/dev/vagrant-local/Vagrantfile
#
#

# Consul variables
consul_install=$(echo "${CONSUL_INSTALL:-true}" | tr '[:upper:]' '[:lower:]')
consul_install=$(if [[ "$consul_install" == "true" || "$consul_install" == "1" ]]; then echo true; else echo false; fi)
consul_host_port=${CONSUL_HOST_PORT:-8500}
consul_version=${CONSUL_VERSION:-"1.4.1"}
consul_ent_url=${CONSUL_ENT_URL}
consul_group="consul"
consul_user="consul"
consul_comment="Consul"
consul_home="/opt/consul"

# Vault variables
vault_install=$(echo "${VAULT_INSTALL:-true}" | tr '[:upper:]' '[:lower:]')
vault_install=$(if [[ "$vault_install" == "true" || "$vault_install" == "1" ]]; then echo true; else echo false; fi)
vault_host_port=${VAULT_HOST_PORT:-8200}
vault_version=${VAULT_VERSION:-"1.0.2"}
vault_ent_url=${VAULT_ENT_URL}
vault_group="vault"
vault_user="vault"
vault_comment="Vault"
vault_home="/opt/vault"

# Nomad variables
nomad_host_port=${NOMAD_HOST_PORT:-4646}
nomad_version=${NOMAD_VERSION:-"0.8.7"}
nomad_ent_url=${NOMAD_ENT_URL}
nomad_group="root"
nomad_user="root"

# Docker and Java installation flags
docker_install=$(echo "${DOCKER_INSTALL:-true}" | tr '[:upper:]' '[:lower:]')
docker_install=$(if [[ "$docker_install" == "true" || "$docker_install" == "1" ]]; then echo true; else echo false; fi)

java_install=$(echo "${JAVA_INSTALL:-true}" | tr '[:upper:]' '[:lower:]')
java_install=$(if [[ "$java_install" == "true" || "$java_install" == "1" ]]; then echo true; else echo false; fi)


# execute the base script
echo "Running `base.sh`"
./base.sh

# install and configure the Consul server
echo "Creating consul user using `create_user.sh`"
USER=$consul_user GROUP=$consul_group \
  COMMENT=$consul_comment HOME=$consul_home \
  ../consul/scripts/create_user.sh

VERSION=$consul_version URL=$consul_ent_url \
  USER=$consul_user GROUP=$consul_group \
  ../consul/scripts/install_consul.sh

../consul/scripts/install-consul-systemd.sh

# install and configure the Vault server

echo "Creating vault user using `create_user.sh`"
USER=$vault_user GROUP=$vault_group \
  COMMENT=$vault_comment HOME=$vault_home \
  ../vault/scripts/create_user.sh

VERSION=$vault_version URL=$vault_ent_url \
  USER=$vault_user GROUP=$vault_group \
  ../vault/scripts/install_vault.sh

# install and configure the Nomad server
echo "Creating nomad user using `create_user.sh`"
USER=$nomad_user GROUP=$nomad_group \
  COMMENT=$nomad_comment HOME=$nomad_home \
  ../nomad/scripts/create_user.sh

VERSION=$nomad_version URL=$nomad_ent_url \
  USER=$nomad_user GROUP=$nomad_group \
  ../nomad/scripts/install_nomad.sh

../nomad/scripts/install-nomad-systemd.sh

# Check if variables are set
if [[ "$install_docker" == "true" ]]; then
  # Install Docker if not already installed
  if ! command -v docker >/dev/null 2>&1; then
    echo "Installing Docker..."
    ./install-docker.sh
  fi
fi

if [[ "$install_java" == "true" ]]; then
  # Install Java if not already installed
  if ! command -v java >/dev/null 2>&1; then
    echo "Installing Java..."
    .scripts/install-java.sh
  fi
fi