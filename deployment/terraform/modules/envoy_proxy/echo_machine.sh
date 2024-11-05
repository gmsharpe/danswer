#!/bin/bash

# Set up variables
APP_DIR="echo_service"
IMAGE_NAME="echo-service"
CONTAINER_PORT=8080
HOST_PORT=8080

# Create project directory
mkdir -p $APP_DIR
cd $APP_DIR

# Create the Python app (app.py)
cat > app.py <<EOL
from http.server import BaseHTTPRequestHandler, HTTPServer

class SimpleHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header("Content-type", "text/plain")
            self.end_headers()
            self.wfile.write(b"Health check OK")
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    server_address = ('', 8080)
    httpd = HTTPServer(server_address, SimpleHandler)
    print("Starting server on port 8080")
    httpd.serve_forever()
EOL

# Create the Dockerfile
cat > Dockerfile <<EOL
FROM python:3.8-slim

WORKDIR /app

COPY app.py /app

EXPOSE 8080

CMD ["python", "app.py"]
EOL

# Build the Docker image
docker build -t $IMAGE_NAME .

# Run the Docker container
docker run -d -p $HOST_PORT:$CONTAINER_PORT --name $IMAGE_NAME $IMAGE_NAME

# Confirm that the container is running
if [ $? -eq 0 ]; then
  echo "Docker container '$IMAGE_NAME' is running and available at http://localhost:$HOST_PORT/health"
else
  echo "Failed to start Docker container '$IMAGE_NAME'."
fi
