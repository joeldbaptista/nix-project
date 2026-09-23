# Ephemeral layer: every resource billed by the hour. Destroying this layer
# takes the environment's cost from roughly 38 EUR a month to roughly 1 EUR a
# month, and applying it again takes a few minutes. The env-down and env-up
# workflows do exactly that.
#
# The dependency runs one way only. This layer reads the durable layer's
# outputs, and the durable layer never reads anything from here.

data "terraform_remote_state" "durable" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "durable/terraform.tfstate"
    region = var.region
  }
}

locals {
  durable = data.terraform_remote_state.durable.outputs
}

module "endpoints" {
  source = "../../modules/endpoints"

  project            = var.project
  region             = var.region
  vpc_id             = local.durable.vpc_id
  private_subnet_ids = local.durable.private_subnet_ids
  endpoints_sg_id    = local.durable.endpoints_sg_id
  single_az          = var.single_az_endpoints
}

module "ecs_service" {
  source = "../../modules/ecs_service"

  cluster_arn         = local.durable.cluster_arn
  task_definition_arn = local.durable.task_definition_arn
  namespace_id        = local.durable.namespace_id
  subnet_ids          = module.endpoints.task_subnet_ids
  tasks_sg_id         = local.durable.tasks_sg_id
  desired_count       = var.desired_count

  # The task cannot pull its image until the endpoints exist, and Terraform
  # cannot infer that from the arguments above, so it is stated explicitly.
  depends_on = [module.endpoints]
}

module "bastion" {
  source = "../../modules/bastion"

  project       = var.project
  iam_path      = "/${var.project}/"
  subnet_id     = local.durable.public_subnet_ids[0]
  bastion_sg_id = local.durable.bastion_sg_id
  instance_type = var.bastion_instance_type
}
