output "bastion_instance_id" {
  description = "Target for aws ssm start-session."
  value       = module.bastion.instance_id
}

output "service_url" {
  description = "Reachable from the bastion only. There is no public ingress."
  value       = "http://app.${local.durable.namespace_name}:${local.durable.app_port}"
}

output "cluster_name" {
  value = local.durable.cluster_name
}

output "service_name" {
  value = module.ecs_service.service_name
}

output "verify_commands" {
  description = "The Phase 4 acceptance test, with identifiers filled in."
  value = {
    open_session = "aws ssm start-session --target ${module.bastion.instance_id}"
    port_forward = "aws ssm start-session --target ${module.bastion.instance_id} --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters host=app.${local.durable.namespace_name},portNumber=${local.durable.app_port},localPortNumber=8080"
  }
}
