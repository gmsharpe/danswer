variable "vpc_id" {
    description = "The VPC ID to deploy the Consul cluster into"
    default = "vpc-09e5edd417c04b11e"
}
variable "nomad_security_group" {
    default = "sg-05610e06c8916021b"
}
variable "bastion_security_group" {
    default = "sg-0735d18ac363852e1"
}