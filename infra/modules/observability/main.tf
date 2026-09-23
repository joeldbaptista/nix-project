# The log group is durable even though the service that writes to it is not.
# Creating it here rather than letting ECS create it implicitly is what makes
# the retention period enforceable, and retention is the whole cost control for
# CloudWatch Logs.
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project}/app"
  retention_in_days = var.retention_days
}
