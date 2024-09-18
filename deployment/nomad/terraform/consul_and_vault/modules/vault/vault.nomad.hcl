# https://www.hashicorp.com/blog/running-vault-on-nomad-part-2
job "vault" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "primary"

  group "vault" {
    count = 1

    volume "vault" {
      type      = "host"
      read_only = false
      source    = "vault"
    }

    network {
      mode = "host"
      port "vault_api" {
        to = 8200
        static = 8200
      }
      port "vault_cluster" {
        to = 8201
        static = 8201
      }
    }

    task "vault" {
      driver = "docker"

      service {
        name = "vault"
        port = "vault_api"
        provider = "nomad"

        tags = ["vault", "dev"]
        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      config {
        image = "hashicorp/vault:latest"
        ports = ["vault_api", "vault_cluster"]
        # cap_add = ["ipc_lock"]
      }

      template {
        data = <<EOH
ui = true
"disable_mlock" = true
listener "tcp" {
 address         = "0.0.0.0:8200"
 cluster_address = "0.0.0.0:8201"
 tls_disable     = "true"
}
"backend" = {
  "file" = {
       "path" = "/vault/data"
     }
}
cluster_addr = "http://{{ env "NOMAD_IP_cluster" }}:8201"
api_addr     = "http://{{ env "NOMAD_IP_api" }}:8200"

EOH

        destination = "local/config/config.hcl"
        change_mode = "noop"
      }

      env {
        VAULT_DEV = "true"
        #VAULT_API_ADDR = "0.0.0.0:8200"
#         VAULT_LOCAL_CONFIG = <<EOL
# {
#   "backend": {
#     "file": {
#       "path": "/vault/data"
#     }
#   },
#   "listener": {
#     "tcp": {
#       "address": "[::]:8200",
#       "cluster_address": "[::]:8201"
#       "tls_disable": 1
#     }
#   },
#   "ui": true,
#   "disable_mlock": true
# }
# EOL
      }

      resources {
        cpu    = 500
        memory = 512
      }

      volume_mount {
        volume      = "vault"
        destination = "/vault/data"
      }
    }
  }
}
