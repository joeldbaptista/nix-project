output "instance_id" {
  description = "Target for aws ssm start-session."
  value       = aws_instance.bastion.id
}

output "role_arn" {
  value = aws_iam_role.bastion.arn
}
