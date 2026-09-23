# Interface endpoints are the largest hourly cost in the project, at roughly
# 0.011 USD per endpoint per availability zone per hour. They are billed for
# existing, not for being used, and they cannot be stopped. That is why they
# sit in the ephemeral layer and are destroyed rather than left idle.
#
# Three are required for a Fargate task in a subnet with no internet route:
#   ecr.api  - authentication and image manifest calls
#   ecr.dkr  - the Docker Registry protocol itself
#   logs     - the awslogs driver's PutLogEvents calls
# Image layers themselves come from S3, through the free gateway endpoint that
# the network module attaches to the private route table.

locals {
  services = ["ecr.api", "ecr.dkr", "logs"]

  # Each endpoint is billed per availability zone, so a development environment
  # halves its cost by placing them in one subnet only.
  subnet_ids = var.single_az ? slice(var.private_subnet_ids, 0, 1) : var.private_subnet_ids
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.services)

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.subnet_ids
  security_group_ids  = [var.endpoints_sg_id]
  private_dns_enabled = true

  tags = { Name = "${var.project}-${each.value}" }
}
