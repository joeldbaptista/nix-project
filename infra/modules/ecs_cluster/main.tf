# The cluster itself is free and holds no running capacity, so it belongs to
# the durable layer. The service that runs tasks on it is ephemeral.
resource "aws_ecs_cluster" "this" {
  name = var.project

  setting {
    name  = "containerInsights"
    value = "disabled" # Container Insights is billed per metric, so it stays off.
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# The namespace is a Route 53 private hosted zone, which is durable and costs
# about half a euro a month. The service registration inside it is ephemeral.
resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = "${var.project}.internal"
  vpc         = var.vpc_id
  description = "Private DNS for ${var.project}. There is no load balancer, so this is how the service is addressed."
}

# ---------------------------------------------------------------------------
# Task definition. Terraform owns this first revision. Every later revision is
# registered by the app pipeline with a new image tag, which is why the service
# ignores changes to its task_definition attribute.
# ---------------------------------------------------------------------------
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${var.repository_url}:${var.initial_image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = var.app_port
          protocol      = "tcp"
        },
      ]

      # The image carries no curl, so the check uses the interpreter that is
      # already present rather than adding a package for the purpose.
      healthCheck = {
        command = [
          "CMD-SHELL",
          "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:${var.app_port}/health')\" || exit 1",
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "app"
        }
      }
    },
  ])
}
