# Durable layer: everything that is free or nearly free, and that therefore
# stays applied permanently. Nothing here is billed by the hour except the
# private hosted zone behind the Cloud Map namespace, at roughly half a euro a
# month. This layer must never depend on the ephemeral layer.

module "network" {
  source = "../../modules/network"

  project  = var.project
  region   = var.region
  vpc_cidr = var.vpc_cidr
  az_count = var.az_count
}

module "security" {
  source = "../../modules/security"

  project  = var.project
  vpc_id   = module.network.vpc_id
  vpc_cidr = module.network.vpc_cidr
  app_port = var.app_port
}

module "ecr" {
  source = "../../modules/ecr"

  project = var.project
}

module "observability" {
  source = "../../modules/observability"

  project        = var.project
  retention_days = var.log_retention_days
}

module "iam" {
  source = "../../modules/iam"

  project  = var.project
  iam_path = "/${var.project}/"
}

module "ecs_cluster" {
  source = "../../modules/ecs_cluster"

  project            = var.project
  region             = var.region
  vpc_id             = module.network.vpc_id
  execution_role_arn = module.iam.execution_role_arn
  task_role_arn      = module.iam.task_role_arn
  repository_url     = module.ecr.repository_url
  log_group_name     = module.observability.log_group_name
  app_port           = var.app_port
  task_cpu           = var.task_cpu
  task_memory        = var.task_memory
}
