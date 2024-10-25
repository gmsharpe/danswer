output "cluster_arn" {
  value = aws_ecs_cluster.hybrid_cluster.arn
}

output "frontend_danswer_discovery_service_arn" {
  value = aws_service_discovery_service.front_end_danswer_service.arn
}