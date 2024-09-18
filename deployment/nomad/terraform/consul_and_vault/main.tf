module "vault" {
  source = "./modules/vault"
  vpc_id = var.vpc_id
  bastion_security_group = var.bastion_security_group
    nomad_security_group = var.nomad_security_group
}


# module "consul" {
#   source = "./modules/consul"
# }
