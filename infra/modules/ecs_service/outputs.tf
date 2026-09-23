output "service_name" {
  value = aws_ecs_service.app.name
}

output "service_arn" {
  value = aws_ecs_service.app.id
}

output "discovery_service_arn" {
  value = aws_service_discovery_service.app.arn
}
