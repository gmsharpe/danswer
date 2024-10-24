variable "key_name" {
  type=string
  default = "danswer"
}
variable "availability_zone" {
  type=string
  default = "us-west-1a"
}
variable "bastion_instance_type" {
  type=string
  default = "t2.micro"
}
variable "node_instance_type" {
  type=string
  default = "t2.xlarge"
}
variable "domain_name" {
  type=string
}
variable "use_route53_domain" {
  description = "Flag to indicate whether Route 53 domain related resources should be created"
  type        = bool
  default     = false
}
variable "registration_limit" {
  type    = number
  default = 45
}

variable "expiration_date" {
  type = string
}