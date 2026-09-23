# The bastion exists because the service has no public ingress. It is the only
# way to reach a task in the private subnet, and it is how the acceptance test
# is run.
#
# It sits in a public subnet on purpose. Session Manager is outbound-initiated,
# so a public subnet lets the SSM agent reach the service over the internet
# gateway. Placing it in a private subnet instead would require interface
# endpoints for ssm, ssmmessages and ec2messages, at roughly 22 EUR a month.
# The instance still declares no inbound rule of any kind, so it has no open
# port either way.

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name               = "${var.project}-bastion"
  path               = var.iam_path
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  description        = "Lets the SSM agent register the instance as a managed node."
}

# This managed policy is what makes Session Manager work. Access to the
# instance is therefore controlled by IAM rather than by an SSH key.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project}-bastion"
  path = var.iam_path
  role = aws_iam_role.bastion.name
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.bastion_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  # Required for the SSM agent to reach the service, since this project builds
  # no NAT Gateway. AWS bills every public IPv4 address hourly, which is part
  # of why this instance belongs to the ephemeral layer.
  associate_public_ip_address = true

  # IMDSv2 only. It closes the credential-theft path that a server-side request
  # forgery in any process on the instance would otherwise open.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "${var.project}-bastion" }
}
