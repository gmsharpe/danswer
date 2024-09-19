#!/bin/bash

SERVER_IP=$1

# Create the directories for the Nomad volumes
sudo mkdir -p /var/nomad/volumes/danswer/{db,vespa,nginx,indexing_model_cache_huggingface,model_cache_huggingface}

# Wait for Nomad Server to be ready
retry_count=0
max_retries=3

echo "Waiting for Nomad to start..."
while true; do
  status_code=$(curl -s -o /dev/null -w "%%{http_code}" http://$SERVER_IP:4646/ui/jobs)
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

# Register Nomad Volumes using API
volumes=(
  '{"Name":"db", "Path":"/var/nomad/volumes/danswer/db", "AccessMode":"read-write"}'
  '{"Name":"vespa", "Path":"/var/nomad/volumes/danswer/vespa", "AccessMode":"read-write"}'
  '{"Name":"model_cache_huggingface", "Path":"/var/nomad/volumes/danswer/model_cache_huggingface", "AccessMode":"read-write"}'
  '{"Name":"indexing_model_cache_huggingface", "Path":"/var/nomad/volumes/danswer/indexing_model_cache_huggingface", "AccessMode":"read-write"}'
  '{"Name":"nginx", "Path":"/var/nomad/volumes/danswer/nginx", "AccessMode":"read-write"}'
)

echo "Registering volumes with Nomad..."
for volume in "$${volumes[@]}"; do
  echo "Registering volume: $volume with Nomad at $SERVER_IP:4646"
  curl -X POST "http://$SERVER_IP:4646/v1/volumes/host" \
    -H "Content-Type: application/json" \
    -d "{
      \"Name\": $(echo $volume | jq -r '.Name'),
      \"Type\": \"host\",
      \"PluginID\": \"raw_exec\",
      \"External\": false,
      \"Provider\": \"nomad\",
      \"Options\": {
        \"path\": $(echo $volume | jq -r '.Path')
      },
      \"AccessMode\": $(echo $volume | jq -r '.AccessMode')
    }"
done

sudo systemctl restart nomad