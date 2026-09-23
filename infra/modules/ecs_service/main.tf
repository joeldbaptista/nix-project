# Cloud Map registration. Without a load balancer there is no stable address
# for the service, and a Fargate task receives a new private IP on every
# deployment. This gives it the name app.<project>.internal instead.
resource "aws_service_discovery_service" "app" {
  name = "app"

  dns_config {
    namespace_id = var.namespace_id

    dns_records {
      type = "A"
      ttl  = 10
    }

    routing_policy = "MULTIVALUE"
  }

  # Custom health checking, meaning ECS reports task health to Cloud Map rather
  # than Route 53 probing the task itself. A Route 53 health check cannot reach
  # a private address anyway.
  health_check_custom_config {}
}

resource "aws_ecs_service" "app" {
  name            = "app"
  cluster         = var.cluster_arn
  task_definition = var.task_definition_arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Fargate pulls images and writes logs through the VPC endpoints, so the task
  # needs no public address and the subnet needs no internet route.
  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.tasks_sg_id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.app.arn
  }

  # One task at desired_count 1 means the old task must stop before the new one
  # starts, so a deployment is briefly unavailable. That is acceptable here and
  # it avoids paying for a second task during every rollout.
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  wait_for_steady_state = var.wait_for_steady_state

  lifecycle {
    # The app pipeline registers new task definition revisions and points the
    # service at them, so Terraform must not revert the running image on the
    # next infra apply. Likewise desired_count may be changed by hand to park
    # the service without a Terraform run.
    ignore_changes = [task_definition, desired_count]
  }

  # Note: this service cannot start a task until the interface endpoints exist,
  # because the image pull has no other route out of the private subnet. That
  # ordering is not inferable from these arguments, so the ephemeral layer
  # declares depends_on = [module.endpoints] on the call to this module.
}
