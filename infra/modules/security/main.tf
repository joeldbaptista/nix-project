# Every security group and every rule lives in this one module, so the whole
# access model can be read in a single file. Rules are separate resources rather
# than inline blocks, which is what allows groups to reference each other
# without creating a dependency cycle.

resource "aws_security_group" "tasks" {
  name        = "${var.project}-tasks"
  description = "ECS tasks. Reachable only from the bastion, and may talk only to the VPC endpoints."
  vpc_id      = var.vpc_id

  tags = { Name = "${var.project}-tasks" }
}

resource "aws_security_group" "endpoints" {
  name        = "${var.project}-endpoints"
  description = "VPC interface endpoints. Accepts HTTPS from tasks and bastion only."
  vpc_id      = var.vpc_id

  tags = { Name = "${var.project}-endpoints" }
}

resource "aws_security_group" "bastion" {
  name        = "${var.project}-bastion"
  description = "SSM-managed bastion. No inbound rules at all, because Session Manager is outbound-initiated."
  vpc_id      = var.vpc_id

  tags = { Name = "${var.project}-bastion" }
}

# ---------------------------------------------------------------------------
# Tasks: one way in, one way out.
# ---------------------------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "tasks_from_bastion" {
  security_group_id            = aws_security_group.tasks.id
  description                  = "Application port, from the bastion only."
  referenced_security_group_id = aws_security_group.bastion.id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
}

resource "aws_vpc_security_group_egress_rule" "tasks_to_endpoints" {
  security_group_id            = aws_security_group.tasks.id
  description                  = "HTTPS to the interface endpoints, for image pulls and log writes."
  referenced_security_group_id = aws_security_group.endpoints.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

# ---------------------------------------------------------------------------
# Endpoints: accept HTTPS, originate nothing.
# ---------------------------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "endpoints_from_tasks" {
  security_group_id            = aws_security_group.endpoints.id
  description                  = "HTTPS from ECS tasks."
  referenced_security_group_id = aws_security_group.tasks.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_bastion" {
  security_group_id            = aws_security_group.endpoints.id
  description                  = "HTTPS from the bastion."
  referenced_security_group_id = aws_security_group.bastion.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

# ---------------------------------------------------------------------------
# Bastion: no ingress rules are declared anywhere, deliberately.
# ---------------------------------------------------------------------------
resource "aws_vpc_security_group_egress_rule" "bastion_https" {
  security_group_id = aws_security_group.bastion.id
  description       = "HTTPS for the outbound SSM agent control and data channels."
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "bastion_to_tasks" {
  security_group_id            = aws_security_group.bastion.id
  description                  = "Application port, for the acceptance test."
  referenced_security_group_id = aws_security_group.tasks.id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
}

# DNS resolution goes to the VPC resolver at the base of the CIDR, which is not
# a security group member, so it needs an explicit CIDR rule.
resource "aws_vpc_security_group_egress_rule" "bastion_dns_udp" {
  security_group_id = aws_security_group.bastion.id
  description       = "DNS to the VPC resolver."
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
}

# ECR stores image layers in S3, and a task fetches them through the free S3
# gateway endpoint. That traffic is addressed to S3's public address range
# rather than to an endpoint network interface, so a rule referencing the
# endpoints security group does not cover it. Without this rule an image pull
# fails with a connection timeout.
resource "aws_vpc_security_group_egress_rule" "tasks_to_s3" {
  security_group_id = aws_security_group.tasks.id
  description       = "HTTPS to S3 through the gateway endpoint, for ECR image layers."
  prefix_list_id    = var.s3_prefix_list_id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "tasks_dns_udp" {
  security_group_id = aws_security_group.tasks.id
  description       = "DNS to the VPC resolver."
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
}
