output "repository_url" {
  description = "Registry path the pipelines push to and the task definition pulls from."
  value       = aws_ecr_repository.app.repository_url
}

output "repository_name" {
  value = aws_ecr_repository.app.name
}

output "repository_arn" {
  value = aws_ecr_repository.app.arn
}
