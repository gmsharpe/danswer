module "nomad_ec2_cluster" {
  source = "./modules/nomad_ec2_cluster"
}


# module "danswer" {
#   source = "./modules/danswer_job"
#   depends_on = [ module.nomad_ec2_cluster ] # , module.consul, module.vault ]
#   encryption_key_secret = "not_a_real_danswer_encryption_key"
# }

