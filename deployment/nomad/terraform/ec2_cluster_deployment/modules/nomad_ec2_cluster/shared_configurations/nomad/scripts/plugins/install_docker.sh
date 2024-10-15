#!/bin/bash

nomad_user=${1:-"nomad"}

# Install Docker
sudo yum install -y docker

# Start Docker and enable it to start on boot
sudo systemctl start docker
sudo systemctl enable docker

# todo - add the nomad user to the docker group.  not doing this for now because we are running nomad as root.
#sudo usermod -aG docker $nomad_user

# Configure Docker Daemon - Ensure Docker uses the systemd cgroup driver, which is recommended for
# compatibility with systemd and Nomad.
sudo mkdir -p /etc/docker
sudo nano /etc/docker/daemon.json

sudo systemctl restart docker

# Define the content to append
content=$(cat <<EOF

plugin "docker" {
  config {
    allow_privileged = true
    volumes {
      enabled = true
    }
  }
}
EOF
)

# Append the content to the nomad.hcl file using sudo
echo "$content" | sudo tee -a /etc/nomad.d/nomad.hcl > /dev/null

# Verify the content was added
echo "Docker plugin configuration has been appended to /etc/nomad.d/nomad.hcl"

sudo systemctl restart nomad