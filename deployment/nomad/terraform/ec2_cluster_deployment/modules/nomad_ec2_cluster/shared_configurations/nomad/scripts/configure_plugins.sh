#!/bin/bash
plugins=$1

if [ "$#" -gt 0 ]; then
    # Capture all arguments as an array
    plugins=("$@")
else
    # Default array if no arguments are passed
    plugins=("java" "docker" "raw_exec")
fi

for plugin in "${plugins[@]}"; do
    case "$plugin" in
        "java")
            echo "Installing and configuring Java plugin!"
            plugins/install_java.sh
            ;;
        "docker")
            echo "Installing and configuring Docker plugin!"
            plugins/install_docker.sh
            ;;
        "raw_exec")
            echo "Configuring 'raw_exec' plugin!"
            ;;
        *)
            echo "Unknown item! ($plugin) Skipping..."
            ;;
    esac
done
