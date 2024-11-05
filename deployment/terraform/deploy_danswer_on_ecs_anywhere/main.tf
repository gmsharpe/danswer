module "envoy_proxy" {
  source            = "../modules/envoy_proxy"
  consul_token_secret_id = module.consul_server.consul_secret_id

  consul_ca_cert_secret_id     = "danswer-ca-cert"

  consul_server_cert_secret_id = "danswer-server-cert"
  consul_client_key_secret_id  = "danswer-ca-key"
}

module "ec2_cluster" {
  source      = "../modules/ecs_anywhere_ec2_cluster"
  domain_name = "edumore.io"


  expiration_date                               = "2024-10-31T07:00:00Z"
  ecs_optimized_instance_count                  = 0
  external_launch_type_ec2_container_host_count = 0
}

module "danswer" {
  source                                 = "../modules/danswer"
  cluster_arn                            = module.ec2_cluster.cluster_arn
  frontend_danswer_discovery_service_arn = module.ec2_cluster.frontend_danswer_discovery_service_arn
}

module "consul_server" {
  cluster_size       = 0
  source             = "../modules/consul_server"
  vpc_id             = module.ec2_cluster.vpc_id
  subnets            = module.ec2_cluster.private_subnets
  cluster_arn        = module.ec2_cluster.cluster_arn
  consul_image       = "hashicorp/consul:1.20"
  bastion_host_sg_id = module.ec2_cluster.bastion_host_sg_id

  service_discovery_namespace = "services.danswer-internal.danswer.edumore.io"

  datacenter        = "dc1"
  ecs_service_sg_id = module.ec2_cluster.ecs_service_sg_id

  acls        = true
  generate_ca = true
  tls         = true
  lb_enabled  = false
  lb_arn      = "arn:aws:elasticloadbalancing:us-west-1:736682772784:loadbalancer/app/edumore-alb/cd81a3b6972e9d86"
}

module "vpn" {
  source = "../modules/vpn"
  vpc_id = module.ec2_cluster.vpc_id

  server_certificate_arn = "arn:aws:acm:us-west-1:736682772784:certificate/f1d7c202-74c0-4481-bccf-003d5cbfcde8"
  # client cert arn
  # arn:aws:acm:us-west-1:736682772784:certificate/0366d39c-374c-4ad5-91cd-0a8c855b00f5
  subnet_ids             = module.ec2_cluster.private_subnets
  vpn_enabled            = true
}

output "activation_code" {
  value = module.ec2_cluster.activation_code
}

output "activation_id" {
  value = module.ec2_cluster.activation_id
}

output "subnet_ids" {
  value = module.ec2_cluster.private_subnets
}