job "ollama_service" {
  datacenters = ["dc1"]  # Specify your datacenters
  type        = "service"

  group "ollama_group" {
    count = 1  # Number of instances of this group

    # Define the ollama_volume for persistent storage
    volume "ollama_volume" {
      type      = "host"
      read_only = false
      source    = "/path/to/ollama"  # Adjust the path on the host machine
    }

    # CPU-only Ollama Task
    task "ollama_cpu" {
      driver = "docker"

      config {
        image = "ollama/ollama:latest"

        # Mount volume for Ollama data
        volumes = ["ollama_volume:/root/.ollama"]

        # Set the container to run in the background with the appropriate port
        ports = ["11434"]
      }

      # Resources for the CPU task
      resources {
        cpu    = 1000   # 1000 MHz (1 core)
        memory = 1024   # 1 GB of RAM
        network {
          port "http" {
            static = 11434  # Expose Ollama on port 11434
          }
        }
      }

      # Restart policy
      restart {
        attempts = 2
        interval = "5m"
        delay    = "25s"
        mode     = "delay"
      }

      # Volume mount for Ollama data
      volume_mount {
        volume      = "ollama_volume"
        destination = "/root/.ollama"
      }
    }
  }
}
