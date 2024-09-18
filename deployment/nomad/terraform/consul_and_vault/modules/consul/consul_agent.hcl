job "consul_agent" {
  datacenters = ["${datacenter}"]

  group "consul_clients" {
    count = 1

    task "consul" {
      driver = "docker"

      config {
        image = "hashicorp/consul:${consul_version}"
        args  = ["agent", "-client=0.0.0.0", "-datacenter=${datacenter}", "-retry-join=provider=nomad", "-bind=0.0.0.0"]
      }

      resources {
        cpu    = 250
        memory = 128
      }

      service {
        name = "consul"
        tags = ["global", "client"]
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
