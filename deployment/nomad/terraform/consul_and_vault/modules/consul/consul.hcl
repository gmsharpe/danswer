job "consul" {
  datacenters = ["${datacenter}"]

  group "consul_servers" {
    count = 3

    task "consul" {
      driver = "docker"

      config {
        image = "hashicorp/consul:${consul_version}"
        args  = ["agent", "-server", "-bootstrap-expect=3", "-client=0.0.0.0", "-datacenter=${datacenter}"]
      }

      resources {
        cpu    = 500
        memory = 256
      }

      service {
        name = "consul"
        tags = ["global", "server"]
        port = "8500"
        address_mode = "host"
      }

      network {
        port "8500" {
          static = 8500
        }
      }

      volume {
        path      = "local:/consul/data"
        read_only = false
      }

      artifact {
        source      = "https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip"
        destination = "local/consul.zip"
      }
    }
  }
}
