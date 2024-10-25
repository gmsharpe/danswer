#### NOTE: The following is a 'living' document representing a dialogue with gen-ai (e.g. chatGPT) to derive the steps for deploying envoy and consul

It’s possible to configure Envoy with Consul for service discovery and proxying without deploying Consul clients on the
ECS Anywhere nodes themselves. In this case, you will only run the Consul server (accessible in AWS EC2) and have Envoy
sidecars on your ECS Anywhere tasks retrieve their configuration (xDS) directly from the central Consul server. Here’s
how you can achieve this:

### Central Consul Server in AWS EC2
You will have a central Consul server deployed on AWS EC2 instances that provides the following:

Service discovery and health checking for services running in the ECS Anywhere nodes.
Management of xDS configuration for Envoy sidecars (Envoy acts as a client to the Consul server).
Serve dynamic configurations for Envoy proxies over gRPC or HTTP (via the xDS API).

Ensure that:

The Consul server is configured and accessible from the ECS Anywhere nodes.
Consul server's firewall and security group rules allow access to required ports (default is 8500 for HTTP and 8502
for gRPC/xDS).

### Run Envoy as a Sidecar on ECS Anywhere
Each ECS task that requires service discovery and proxying will have an Envoy sidecar. Since you are not running
a Consul client on the ECS nodes, Envoy will directly connect to the central Consul server to fetch service
discovery data and configuration dynamically.

#### Envoy Configuration
You’ll need to configure Envoy’s bootstrap to connect directly to the central Consul server to retrieve xDS
configurations. This bootstrap configuration is necessary to get Envoy connected to the Consul server.
Example Envoy bootstrap configuration (JSON format):


```
{
  "node": {
    "id": "envoy-sidecar",
    "cluster": "ecs-anywhere-services"
  },
  "dynamic_resources": {
    "lds_config": {
      "ads": {}
    },
    "cds_config": {
      "ads": {}
    },
    "ads_config": {
      "api_type": "GRPC",
      "grpc_services": [
        {
          "envoy_grpc": {
            "cluster_name": "xds_cluster"
          }
        }
      ]
    }
  },
  "static_resources": {
    "clusters": [
      {
        "name": "xds_cluster",
        "type": "STRICT_DNS",
        "connect_timeout": "5s",
        "dns_lookup_family": "V4_ONLY",
        "lb_policy": "ROUND_ROBIN",
        "load_assignment": {
          "cluster_name": "xds_cluster",
          "endpoints": [
            {
              "lb_endpoints": [
                {
                  "endpoint": {
                    "address": {
                      "socket_address": {
                        "address": "<CONSUL_SERVER_IP>",
                        "port_value": 8502
                      }
                    }
                  }
                }
              ]
            }
          ]
        }
      }
    ]
  }
}

```

* `<CONSUL_SERVER_IP>`: Replace with the IP address or DNS name of your Consul server running in AWS EC2.
* `Port 8502`: The default port used for gRPC communication between Envoy and Consul for xDS configuration.

#### ECS Task Definition
Your ECS task definition will need to include the Envoy container as a sidecar. Here's an example task definition with
both the application container and the Envoy sidecar:

```
{
  "containerDefinitions": [
    {
      "name": "my-app",
      "image": "<your-app-image>",
      "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080
        }
      ]
    },
    {
      "name": "envoy",
      "image": "envoyproxy/envoy:v1.18.3",
      "essential": true,
      "environment": [
        {
          "name": "CONSUL_HTTP_ADDR",
          "value": "http://<CONSUL_SERVER_IP>:8500"
        }
      ],
      "portMappings": [
        {
          "containerPort": 19000,
          "hostPort": 19000
        }
      ],
      "command": [
        "envoy",
        "-c",
        "/etc/envoy/envoy_bootstrap.json"
      ]
    }
  ]
}

```

#### Application container
Your main service container (e.g., my-app) listens on port 8080.
Envoy sidecar: This is the Envoy proxy that will intercept traffic, fetch its configuration from the Consul server, and
route traffic based on service discovery data. It uses the bootstrap configuration file (envoy_bootstrap.json) to
connect to Consul’s xDS API.

### Consul Service Registration

Since the ECS Anywhere nodes don’t have a Consul client, you will need to register services directly with the Consul server.

There are two ways you can register ECS Anywhere services with Consul:

#### Manual Registration: 
You can manually define the services in Consul’s configuration and register them using the Consul
CLI or API.

Example service registration for a service running on an ECS Anywhere node:

```
{
    "ID": "my-app",
    "Name": "my-app",
    "Tags": ["ecs-anywhere"],
    "Address": "172.31.25.10",
    "Port": 8080
}
```

You can automate this registration via ECS task events, or if you have an orchestration layer that knows the service IPs
and ports, it can push this data to Consul.

#### External Service Discovery: 
You could potentially use an external mechanism to register ECS Anywhere services with
Consul (e.g., a script or tool that runs on the Consul server and registers new services based on ECS task metadata or
DNS lookups).

### Service-to-Service Communication via Envoy

Once Envoy is running as a sidecar on the ECS tasks, it will automatically handle service discovery and traffic routing based on the dynamic configuration provided by Consul.
Consul will serve as the control plane, dynamically configuring Envoy proxies for routing, load balancing, and
enforcing service-to-service policies (e.g., mTLS, intentions).

### Monitoring and Metrics
Expose metrics using the envoy_prometheus_bind_addr configuration.
You can scrape Envoy’s metrics using Prometheus and visualize them in Grafana for real-time monitoring of traffic and performance.

### Security Considerations
Make sure that the Envoy containers have access to the Consul server securely. This can be done over a VPN, private network, or by enabling Consul’s built-in TLS features to secure communication between the server and Envoy clients.
Use Consul ACL tokens to restrict access to the API and ensure that Envoy proxies can only fetch the configurations they are authorized to retrieve.

## Key Considerations:
* No Consul Client on ECS Anywhere: Since you are not running Consul clients on the ECS Anywhere nodes, service
registration will need to be handled externally or manually.

* Direct Envoy-Consul Communication: Envoy proxies on ECS Anywhere nodes communicate directly with the central Consul
server using xDS APIs.

* Service Discovery: Consul will provide dynamic service discovery information to Envoy proxies, allowing them to
automatically discover and route traffic to other services in the mesh.

This approach provides a lightweight deployment model where you don’t need to manage Consul agents on ECS Anywhere
nodes, relying instead on a central Consul server to manage service discovery and dynamic configuration for Envoy
proxies.