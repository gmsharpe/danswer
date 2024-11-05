#!/bin/bash

# Check if the token argument is provided
if [ -z "$1" ]; then
  echo "Usage: ./register_service.sh <token>"
  exit 1
fi

TOKEN=$1
echo "Using token: $TOKEN"

# Define the path to the temporary JSON file
CONFIG_FILE="echo-service-config.json"

# Write the JSON configuration to the file
cat > $CONFIG_FILE <<EOL
{
  "service": {
    "name": "echo-service",
    "id": "echo-service-1",
    "connect": {
      "sidecar_service": {
        "proxy": {
          "upstreams": [
            {
              "destination_name": "echo-2",
              "local_bind_port": 19000
            }
          ]
        }
      }
    }
  },
  "check": {
    "tcp": "10.0.1.10:19000",
    "interval": "10s",
    "timeout": "1s",
    "deregister_critical_service_after": "90m"
  }
}
EOL

# Register the service with Consul using the JSON config file
consul services register -token="$TOKEN" $CONFIG_FILE

# Check the response code
if [ $? -eq 0 ]; then
  echo "echo-service registered successfully with Consul."
else
  echo "Failed to register echo-service with Consul."
fi

# Clean up the temporary JSON file
rm -f $CONFIG_FILE
