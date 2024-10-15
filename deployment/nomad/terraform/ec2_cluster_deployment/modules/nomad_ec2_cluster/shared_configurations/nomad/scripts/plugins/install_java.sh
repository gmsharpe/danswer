#!/bin/bash

version=${1:-"23"}

# todo - this should be replaced with a department/team specific process)

# Install Java if not already installed
if ! command -v java &> /dev/null
then
    echo "Java is not installed. Installing Java $version..."
    echo "actually, doing nothing for now.... to be implemented later"
else
    echo "Java is already installed. Skipping..."
fi