#!/bin/bash


# Update and install prerequisites
yum update -y && yum install -y wget unzip

consul_version=1.20.1
envoy_version=1.32.0

# Check if Consul is installed
if command -v consul &> /dev/null; then
  echo "Consul is already installed. Skipping installation."
else
  echo "Installing Consul version $consul_version..."
  wget -O /tmp/consul.zip "https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip"
  unzip /tmp/consul.zip -d /usr/local/bin/
  chmod +x /usr/local/bin/consul
  rm /tmp/consul.zip
  consul --version
fi

# Check if Envoy is installed
if command -v envoy &> /dev/null; then
  echo "Envoy is already installed. Skipping installation."
else
  echo "Installing Envoy version $envoy_version..."
  wget -O /tmp/envoy "https://github.com/envoyproxy/envoy/releases/download/v${envoy_version}/envoy-${envoy_version}-linux-x86_64"
  sudo mv /tmp/envoy /usr/local/bin/envoy
  sudo chmod +x /usr/local/bin/envoy
  envoy --version
fi

echo "Installation script completed."


export CONSUL_HTTP_TOKEN=""
export CONSUL_CACERT="/ca-cert.pem"
export CONSUL_CLIENT_CERT="client-cert.pem"
export CONSUL_CLIENT_KEY="/client-key.pem"
export CONSUL_HTTP_SSL=true

# consul connect envoy -sidecar-for danswer -envoy-binary /usr/local/bin/envoy -token $CONSUL_HTTP_TOKEN
