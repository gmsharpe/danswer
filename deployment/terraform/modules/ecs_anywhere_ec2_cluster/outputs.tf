output "cluster_arn" {
  value = aws_ecs_cluster.hybrid_cluster.arn
}

output "frontend_danswer_discovery_service_arn" {
  value = aws_service_discovery_service.front_end_danswer_service.arn
}

output "vpc_id" {
  value = aws_vpc.ecs_anywhere_vpc.id
}

output "private_subnets" {
    value = aws_subnet.ecs_anywhere_subnet[*].id
}

output "public_subnets" {
  value = aws_subnet.bastion_subnet[*].id
}

output "danswer_internal_zone_id" {
  value = aws_route53_zone.private_danswer_internal_zone[0].zone_id
}

output "bastion_host_sg_id" {
  value = aws_security_group.danswer_bastion_sg.id
}

output "ecs_service_sg_id" {
    value = aws_security_group.ecs_anywhere_sg.id
}