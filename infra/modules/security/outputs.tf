output "tasks_sg_id" {
  value = aws_security_group.tasks.id
}

output "endpoints_sg_id" {
  value = aws_security_group.endpoints.id
}

output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}
