resource "aws_ecr_repository" "app" {
  name                 = "${var.project}/app"
  image_tag_mutability = "MUTABLE"

  # Basic scanning is free, so there is no reason to leave it off.
  image_scanning_configuration {
    scan_on_push = true
  }

  # The repository is durable, but its contents are disposable. Allowing
  # Terraform to delete a non-empty repository keeps teardown simple.
  force_delete = true
}

# Every build pushes an immutable commit-SHA tag plus a moving branch tag, so
# untagged layers accumulate on every rebuild of an existing commit.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after one day."
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the most recent ${var.keep_image_count} tagged images."
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.keep_image_count
        }
        action = { type = "expire" }
      },
    ]
  })
}
