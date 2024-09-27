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
    case "$plugins" in
        "java")
            echo "Installing and configuring Java plugin!"
            ;;
        "docker")
            echo "Installing and configuring Docker plugin!"
            ;;
        "raw_exec")
            echo "Configuring 'raw_exec' plugin!"
            ;;
        *)
            echo "Unknown item!"
            ;;
    esac
done
