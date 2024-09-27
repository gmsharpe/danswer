#!/bin/bash

echo "Verifying whether java is installed..."
if ! command -v java &> /dev/null
then
    echo "Java is not installed. Installing..."
    # todo - we should be discerning about what version we use and where we get it from
else
    echo "Java is already installed."
fi