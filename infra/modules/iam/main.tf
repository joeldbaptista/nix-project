data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------
# Execution role. Assumed by the ECS agent, not by the application. It pulls
# the image and writes the log stream, and it is the reason a task in a private
# subnet can start at all.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "execution" {
  name               = "${var.project}-ecs-execution"
  path               = var.iam_path
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
  description        = "Used by the ECS agent to pull images and write logs."
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------------------------------------------------------------------
# Task role. Assumed by the application itself. It starts empty on purpose:
# the service calls no AWS API, so it needs no permission. Permissions get
# added only when a feature actually requires one.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "task" {
  name               = "${var.project}-ecs-task"
  path               = var.iam_path
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
  description        = "Assumed by the application. Deliberately holds no permissions."
}
