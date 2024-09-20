#!/bin/bash

SERVER_IP=$1

# Create the directories for the Nomad volumes
sudo mkdir -p /var/nomad/volumes/danswer/{db,vespa,nginx,indexing_model_cache_huggingface,model_cache_huggingface}

# Copy nginx files
sudo cp -r /opt/danswer/deployment/data/nginx /var/nomad/volumes/danswer

# Wait for Nomad Server to be ready
retry_count=0
max_retries=3

echo "Waiting for Nomad to start..."
while true; do
  status_code=$(curl -s -o /dev/null -w "%{http_code}" http://$SERVER_IP:4646/ui/jobs)
  if [ "$status_code" -eq 200 ]; then
    echo "Nomad is up and running!"
    break
  else
    echo "Nomad is not ready yet (status code: $status_code). Retrying in 5 seconds..."
    sleep 5
    retry_count=$((retry_count + 1))
    if [ $retry_count -eq $max_retries ]; then
      echo "Max retries reached. Nomad is not starting."
      exit 1
    fi
  fi
done

# Base path for the volumes
base_path="/var/nomad/volumes/danswer"

# Array of volume names
volume_names=("db" "vespa" "model_cache_huggingface" "indexing_model_cache_huggingface" "nginx")

# Define the Nomad config file path
nomad_hcl_file="/etc/nomad.d/nomad.hcl"

# Create a function to generate the host_volume block
generate_host_volume_block() {
  local name="$1"
  local path="$2"
  echo "  host_volume \"$name\" {"
  echo "    path      = \"$path\""
  echo "    read_only = false"
  echo "  }"
}

# Read the nomad.hcl file and insert the host_volume blocks
add_host_volumes_to_client_block() {
  local hcl_file="$1"
  local volumes=("$@")
  local inside_client_block=0
  local new_content=""

  while IFS= read -r line; do
    # Check if we are inside the client block
    if [[ $line =~ ^client\ \{ ]]; then
      inside_client_block=1
      new_content+="$line"$'\n'
      continue
    fi

    # If inside the client block, look for the closing brace
    if [[ $inside_client_block -eq 1 ]]; then
      if [[ $line == "}" ]]; then
        # Add host volumes before closing the client block
        for volume_name in "${volume_names[@]}"; do
          volume_path="$base_path/$volume_name"
          new_content+=$(generate_host_volume_block "$volume_name" "$volume_path")$'\n'
        done
        inside_client_block=0
      fi
    fi

    # Append the line to new content
    new_content+="$line"$'\n'
  done < "$hcl_file"

  # Write the new content back to the nomad.hcl file
  echo "$new_content" > "$hcl_file"
}

# Read the Nomad config file and add host volumes
add_host_volumes_to_client_block "$nomad_hcl_file"

echo "Updated $nomad_hcl_file with host_volume blocks."

sudo systemctl restart nomad