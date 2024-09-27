# variable "amazon_linux_2023_ami" {
#   # most recent as of 02/27/2024
#   default = "ami-07619059e86eaaaa2"
# }
variable "key_name" {
    default = "nomad_poc"
}
variable "availability_zone" {
  default = "us-west-1a"
}
variable "bastion_instance_type" {
  default = "t2.micro"
}
variable "nomad_instance_type" {
  default = "t2.large"
}
variable "install_consul" {
  default = true
}
variable "install_nomad" {
  default = true
}
variable "install_vault" {
  default = true
}