module "ec2_cluster" {
  source      = "../modules/ecs_anywhere_ec2_cluster"
  domain_name = "edumore.io"

  expiration_date = "2024-10-31T07:00:00Z"
}

module "danswer" {
  source      = "../modules/danswer"
  cluster_arn = module.ec2_cluster.cluster_arn
  frontend_danswer_discovery_service_arn = module.ec2_cluster.frontend_danswer_discovery_service_arn
}

output "activation_code" {
  value = module.ec2_cluster.activation_code
}

output "activation_id" {
  value = module.ec2_cluster.activation_id
}