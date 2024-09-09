# Description: Nomad task templates for Ollama

# CPU Only task
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

# NVIDIA GPU task
task "ollama_nvidia_gpu" {
  driver = "docker"

  config {
    image = "ollama/ollama:latest"

    # Use NVIDIA GPU
    args = ["--gpus", "all"]

    # Mount volume for Ollama data
    volumes = ["ollama_volume:/root/.ollama"]

    # Set the container to run in the background with the appropriate port
    ports = ["11434"]
  }

  # Resources for GPU task
  resources {
    cpu    = 1000  # 1000 MHz (1 core)
    memory = 4096  # 4 GB of RAM, adjust as needed
    network {
      port "http" {
        static = 11434  # Expose Ollama on port 11434
      }
    }

    # GPU allocation
    gpu {
      count = 1  # Allocate 1 GPU, adjust if needed
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

# AMD GPU task
task "ollama_amd_gpu" {
  driver = "docker"

  config {
    image = "ollama/ollama:rocm"

    # Mount volume for Ollama data
    volumes = ["ollama_volume:/root/.ollama"]

    # Add necessary devices for AMD GPU support
    devices = ["/dev/kfd", "/dev/dri"]

    # Set the container to run in the background with the appropriate port
    ports = ["11434"]
  }

  # Resources for AMD GPU task
  resources {
    cpu    = 1000  # 1000 MHz (1 core)
    memory = 4096  # 4 GB of RAM, adjust as needed
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
