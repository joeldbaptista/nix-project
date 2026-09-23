variable "region" {
  description = "AWS region for every resource in this project."
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Name prefix and IAM path segment for every resource."
  type        = string
  default     = "fortune"
}

variable "github_repo" {
  description = "Repository that may assume the CI roles, in owner/name form."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "github_repo must be in owner/name form, for example octocat/fortune."
  }
}

variable "github_subject_prefix" {
  description = <<-EOT
    The repository portion of the OIDC subject claim, without the trailing
    ":ref:..." or ":environment:..." segment. Leave empty to compose it from
    github_repo, which is the classic format "repo:OWNER/NAME".

    A repository with immutable subject claims enabled sends numeric owner and
    repository IDs instead, as "repo:OWNER@1234/NAME@5678". Those IDs survive a
    rename, which is why GitHub prefers them. Read the exact value with:

      gh api repos/OWNER/NAME/actions/oidc/customization/sub --jq .sub_claim_prefix
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.github_subject_prefix == "" || can(regex("^repo:[^:]+/[^:]+$", var.github_subject_prefix))
    error_message = "github_subject_prefix must look like repo:OWNER/NAME or repo:OWNER@1234/NAME@5678."
  }
}

variable "github_branch" {
  description = "Branch whose workflow runs may assume the plan and app roles."
  type        = string
  default     = "main"
}

variable "github_environment" {
  description = <<-EOT
    GitHub Environment that gates terraform apply. A job declaring this
    environment receives an environment-scoped OIDC subject claim, and the
    apply role trusts only that claim. Therefore an unapproved apply is
    refused by AWS, not merely by GitHub.
  EOT
  type        = string
  default     = "infra-apply"
}

variable "github_lifecycle_environment" {
  description = <<-EOT
    GitHub Environment used by the env-up and env-down workflows. It carries no
    protection rules, because a nightly teardown cannot wait for a reviewer.
    The apply role trusts this subject as well as the gated one, so both
    environments must be treated as equally privileged.
  EOT
  type        = string
  default     = "env-lifecycle"
}

variable "create_oidc_provider" {
  description = <<-EOT
    Set to false if the GitHub OIDC provider already exists in this account.
    An account may hold only one provider per issuer URL, so a second attempt
    fails with EntityAlreadyExists.
  EOT
  type        = bool
  default     = true
}

variable "budget_limit_amount" {
  description = "Monthly budget ceiling. Notifications fire against this figure."
  type        = string
  default     = "50"
}

variable "budget_limit_unit" {
  description = <<-EOT
    Currency of the budget ceiling. AWS Budgets evaluates against the account's
    billing currency, so this must match it. It is USD for most accounts.
  EOT
  type        = string
  default     = "USD"
}

variable "budget_notification_email" {
  description = "Address that receives budget notifications."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.budget_notification_email))
    error_message = "budget_notification_email must be a valid email address."
  }
}
