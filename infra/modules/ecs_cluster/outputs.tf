output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "task_definition_arn" {
  description = "The revision Terraform owns. The service starts from it and the app pipeline replaces it."
  value       = aws_ecs_task_definition.app.arn
}

output "task_definition_family" {
  value = aws_ecs_task_definition.app.family
}

output "namespace_id" {
  value = aws_service_discovery_private_dns_namespace.this.id
}

output "namespace_name" {
  value = aws_service_discovery_private_dns_namespace.this.name
}
