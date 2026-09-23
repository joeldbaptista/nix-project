output "endpoint_ids" {
  value = { for name, ep in aws_vpc_endpoint.interface : name => ep.id }
}

output "task_subnet_ids" {
  description = <<-EOT
    Subnets the ECS service should run in. A task in another zone would still
    reach the endpoint interface across the VPC, but that traffic is billed as
    cross-zone data transfer in both directions. Keeping the task beside the
    endpoints avoids the charge, so the service uses these subnets.
  EOT
  value       = local.subnet_ids
}
