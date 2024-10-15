#!/bin/bash

nomad_user=${1:-"nomad"}

# Install Docker
sudo yum install -y docker

# Start Docker and enable it to start on boot
sudo systemctl start docker
sudo systemctl enable docker

sudo usermod -aG docker $nomad_user

# Configure Docker Daemon - Ensure Docker uses the systemd cgroup driver, which is recommended for
# compatibility with systemd and Nomad.
sudo mkdir -p /etc/docker
sudo nano /etc/docker/daemon.json

sudo systemctl restart docker
