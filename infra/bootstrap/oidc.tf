resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1

  url = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
  oidc_issuer       = "token.actions.githubusercontent.com"

  # The subject claim is composed by GitHub from the run's own context, so a
  # workflow cannot choose it. Its repository portion depends on whether the
  # repository uses immutable subject claims, so it comes from a variable when
  # given and is composed from github_repo otherwise.
  subject_prefix = var.github_subject_prefix != "" ? var.github_subject_prefix : "repo:${var.github_repo}"

  # The three subjects this project uses.
  sub_branch    = "${local.subject_prefix}:ref:refs/heads/${var.github_branch}"
  sub_gated     = "${local.subject_prefix}:environment:${var.github_environment}"
  sub_lifecycle = "${local.subject_prefix}:environment:${var.github_lifecycle_environment}"
}

# Shared trust-policy shape. The audience condition is not optional: without it
# any GitHub Actions run in the world could assume these roles.
data "aws_iam_policy_document" "trust_branch" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = [local.sub_branch]
    }
  }
}

data "aws_iam_policy_document" "trust_environment" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Two subjects, because two environments legitimately reach this role: the
    # reviewer-gated one used by the infra pipeline's apply job, and the
    # unprotected one used by the scheduled env-up and env-down workflows. A
    # nightly teardown cannot wait for a human, so it cannot use the gated
    # environment. The consequence is that anyone who can run a workflow in the
    # lifecycle environment holds the same permissions as an approved apply.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = [local.sub_gated, local.sub_lifecycle]
    }
  }
}
