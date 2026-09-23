# These outputs are the interface the ephemeral layer consumes through its
# terraform_remote_state data source. Removing one breaks that layer, so treat
# this file as a published contract rather than as a convenience.

output "region" {
  value = var.region
}

output "project" {
  value = var.project
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "vpc_cidr" {
  value = module.network.vpc_cidr
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "tasks_sg_id" {
  value = module.security.tasks_sg_id
}

output "endpoints_sg_id" {
  value = module.security.endpoints_sg_id
}

output "bastion_sg_id" {
  value = module.security.bastion_sg_id
}

output "repository_url" {
  value = module.ecr.repository_url
}

output "cluster_arn" {
  value = module.ecs_cluster.cluster_arn
}

output "cluster_name" {
  value = module.ecs_cluster.cluster_name
}

output "task_definition_arn" {
  value = module.ecs_cluster.task_definition_arn
}

output "task_definition_family" {
  value = module.ecs_cluster.task_definition_family
}

output "namespace_id" {
  value = module.ecs_cluster.namespace_id
}

output "namespace_name" {
  value = module.ecs_cluster.namespace_name
}

output "log_group_name" {
  value = module.observability.log_group_name
}

output "app_port" {
  value = var.app_port
}
