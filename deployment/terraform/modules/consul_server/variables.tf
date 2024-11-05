variable "vpc_id" {
  description = "The VPC ID where the ECS cluster is located"
  type        = string
}

variable "subnets" {
  description = "The subnets where the ECS tasks will be deployed"
  type = list(string)
}

variable "cluster_arn" {
  description = "The ARN of the ECS cluster"
  type        = string
}

variable "consul_image" {
  description = "The Consul Docker image"
  type        = string
  default     = "latest"
}

variable "datacenter" {
  description = "The datacenter name."
  type        = string
  default     = "dc1"
}

variable "tls" {
  description = "Whether to enable TLS on the server for the control plane traffic."
  type        = bool
  default     = false
}

variable "acls" {
  description = "Enable ACLs."
  type        = bool
  default     = false
}

variable "replication_token" {
  description = "Replication token."
  type        = string
  default     = ""
}

variable "primary_datacenter" {
  description = "Primary datacenter name."
  type        = string
  default     = ""
}

variable "retry_join_wan" {
  description = "List of addresses for WAN join."
  type        = list(string)
  default     = []
}

variable "primary_gateways" {
  description = "List of primary gateways."
  type        = list(string)
  default     = []
}

variable "enable_cluster_peering" {
  description = "Enable cluster peering."
  type        = bool
  default     = false
}

variable "generate_ca" {
  description = "Controls whether or not a CA key and certificate will automatically be created and stored in Secrets Manager. Default is true. Set this to false and set ca_cert_arn and ca_key_arn to provide pre-existing secrets."
  type        = bool
  default     = true
}

variable "generate_bootstrap_token" {
  description = "Whether to automatically generate a bootstrap token."
  type        = bool
  default     = true
}

variable "bootstrap_token" {
  description = "The Consul bootstrap token. By default a bootstrap token will be generated automatically. This field can be used to explicity set the value of the bootstrap token."
  type        = string
  default     = ""
}

variable "bootstrap_token_arn" {
  description = "The ARN of the Secrets Manager secret containing the Consul bootstrap token. By default a secret will be created automatically."
  type        = string
  default     = ""
}

variable "lb_enabled" {
  default = false
}


variable "node_name" {
  description = "Node name of the Consul server. Defaults to the value of 'var.name'."
  type        = string
  default     = ""
}

variable "name" {
  description = "Name to be used on all the resources as identifier."
  type        = string
  default     = "danswer"
}

variable "service_discovery_namespace" {
  description = "The namespace where the Consul server service will be registered with AWS Cloud Map. Defaults to the Consul server domain name: server.<datacenter>.<domain>."
  type        = string
}

variable "enable_mesh_gateway_wan_federation" {
  description = "Controls whether or not WAN federations via mesh gateways is enabled. Default is false."
  type        = bool
  default     = false
}

variable "lb_ingress_rule_cidr_blocks" {
  description = "CIDR blocks that are allowed access to the load balancer."
  type        = list(string)
  default     = null
}

variable "lb_ingress_rule_security_groups" {
  description = "Security groups that are allowed access to the load balancer."
  type        = list(string)
  default     = null
}

variable "consul_server_startup_timeout" {
  description = "The number of seconds to wait for the Consul server to become available via its ALB before continuing. The default is 300s (5m), which should be enough in most cases."
  type        = number
  default     = 300
}

variable "ca_cert_arn" {
  description = "The Secrets Manager ARN of the Consul CA certificate."
  type        = string
  default     = ""
}

variable "ca_key_arn" {
  description = "The Secrets Manager ARN of the Consul CA certificate key."
  type        = string
  default     = ""
}

variable "wait_for_steady_state" {
  description = "Set wait_for_steady_state on the ECS service. This causes Terraform to wait for the Consul server task to be deployed."
  type        = bool
  default     = false
}

variable "lb_arn" {
  default = null
}
variable "ecs_service_sg_id" { }

variable "bastion_host_sg_id" { }

variable "additional_dns_names" {
  description = "List of additional DNS names to add to the Subject Alternative Name (SAN) field of the server's certificate."
  type        = list(string)
  default     = []
}

variable "log_configuration" {
  description = "Task definition log configuration object (https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LogConfiguration.html)."
  type        = any
  default     = null
}
variable "cluster_size" { }