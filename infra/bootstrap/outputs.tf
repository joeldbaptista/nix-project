output "state_bucket" {
  description = "Bucket holding both layers' state files. Fill this into each layer's backend block."
  value       = aws_s3_bucket.state.id
}

output "region" {
  description = "Region every layer deploys into."
  value       = var.region
}

output "plan_role_arn" {
  description = "Assumed by the infra pipeline's plan job."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Assumed by the infra pipeline's apply job, and by the env-up and env-down workflows."
  value       = aws_iam_role.apply.arn
}

output "app_role_arn" {
  description = "Assumed by the app pipeline."
  value       = aws_iam_role.app.arn
}

output "github_variables_to_set" {
  description = "Repository variables the workflows read. Set them with: gh variable set <name> --body <value>"
  value = {
    AWS_REGION         = var.region
    TF_STATE_BUCKET    = aws_s3_bucket.state.id
    AWS_PLAN_ROLE_ARN  = aws_iam_role.plan.arn
    AWS_APPLY_ROLE_ARN = aws_iam_role.apply.arn
    AWS_APP_ROLE_ARN   = aws_iam_role.app.arn
  }
}
