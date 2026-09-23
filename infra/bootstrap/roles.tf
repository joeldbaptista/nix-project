locals {
  account_id = data.aws_caller_identity.current.account_id

  # Every role this project creates lives under the same IAM path, which is what
  # lets the apply role hold iam:* over its own resources and nothing else.
  project_role_arns = "arn:aws:iam::${local.account_id}:role${local.iam_path}*"
  ecr_repo_arn      = "arn:aws:ecr:${var.region}:${local.account_id}:repository/${var.project}/app"
  ecs_service_arns  = "arn:aws:ecs:${var.region}:${local.account_id}:service/${var.project}/*"
}

# ---------------------------------------------------------------------------
# State bucket access, shared by the plan and apply roles.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "state_access" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  # PutObject and DeleteObject are required even by plan, because S3 native
  # locking writes and removes a .tflock object for the duration of the run.
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }
}

resource "aws_iam_policy" "state_access" {
  name   = "${var.project}-tfstate-access"
  path   = local.iam_path
  policy = data.aws_iam_policy_document.state_access.json
}

# ---------------------------------------------------------------------------
# Plan role: read-only, runs unattended on every push.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "plan" {
  name               = "${var.project}-gha-plan"
  path               = local.iam_path
  assume_role_policy = data.aws_iam_policy_document.trust_branch.json
  description        = "Read-only role used by the infra pipeline's plan job."
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "plan_state" {
  role       = aws_iam_role.plan.name
  policy_arn = aws_iam_policy.state_access.arn
}

# ---------------------------------------------------------------------------
# Apply role: write access, reachable only from the gated environment.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "apply" {
  name               = "${var.project}-gha-apply"
  path               = local.iam_path
  assume_role_policy = data.aws_iam_policy_document.trust_environment.json
  description        = "Write role used by the infra pipeline's apply job, gated by the ${var.github_environment} environment."
}

resource "aws_iam_role_policy_attachment" "apply_poweruser" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy_attachment" "apply_state" {
  role       = aws_iam_role.apply.name
  policy_arn = aws_iam_policy.state_access.arn
}

# PowerUserAccess excludes IAM entirely, but the layers must create the two ECS
# roles. So IAM write access is granted, restricted to this project's IAM path.
data "aws_iam_policy_document" "apply_iam" {
  statement {
    effect  = "Allow"
    actions = ["iam:*"]
    resources = [
      local.project_role_arns,
      "arn:aws:iam::${local.account_id}:policy${local.iam_path}*",
      "arn:aws:iam::${local.account_id}:instance-profile${local.iam_path}*",
    ]
  }
}

resource "aws_iam_role_policy" "apply_iam" {
  name   = "${var.project}-apply-iam"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_iam.json
}

# ---------------------------------------------------------------------------
# App role: push an image and update the service, and nothing else.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "app" {
  name               = "${var.project}-gha-app"
  path               = local.iam_path
  assume_role_policy = data.aws_iam_policy_document.trust_branch.json
  description        = "Deploy role used by the app pipeline. Cannot touch Terraform state or IAM."
}

data "aws_iam_policy_document" "app_deploy" {
  # The authorisation token call is account-wide and cannot be resource-scoped.
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeImages",
    ]
    resources = [local.ecr_repo_arn]
  }

  # RegisterTaskDefinition and DescribeTaskDefinition accept no resource ARN.
  statement {
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
    ]
    resources = [local.ecs_service_arns]
  }

  # Handing a role to ECS is itself a privilege, so it is restricted to this
  # project's roles and to the ECS tasks service.
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [local.project_role_arns]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "app_deploy" {
  name   = "${var.project}-app-deploy"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_deploy.json
}
