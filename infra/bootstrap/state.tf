data "aws_caller_identity" "current" {}

locals {
  # Bucket names are globally unique, so the account ID makes this one unique
  # without requiring a hand-picked name.
  state_bucket_name = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
  iam_path          = "/${var.project}/"
}

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket_name

  # State is the one thing that must survive a mistake, so deletion is blocked.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  # Versioning keeps every past state file forever otherwise, which grows
  # without limit and costs money for no benefit after a few months.
  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # The infra pipeline hands plan files from its plan job to its apply job
  # through this prefix. A run that is never approved leaves its plan behind,
  # so the prefix is swept rather than allowed to accumulate.
  rule {
    id     = "expire-handover-plans"
    status = "Enabled"

    filter {
      prefix = "plans/"
    }

    expiration {
      days = 7
    }
  }
}
