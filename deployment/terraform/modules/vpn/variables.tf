
variable "vpn_enabled" {
    description = "Enable Client VPN"
    default     = false
}

variable "vpc_id" {
  description = "The VPC where the Client VPN will connect"
}

variable "subnet_ids" {
  description = "List of subnet IDs for VPN target network association"
}

variable "vpn_cidr" {
  description = "The CIDR range for VPN clients"
  default     = "172.30.0.0/16" # 10.0.100.0/24
}

variable "server_certificate_arn" {
  description = "ARN of the server certificate for Client VPN"
}
