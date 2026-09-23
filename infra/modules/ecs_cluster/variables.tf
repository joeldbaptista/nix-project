variable "project" {
  description = "Name prefix for every resource."
  type        = string
}

variable "region" {
  description = "Region, needed by the awslogs driver."
  type        = string
}

variable "vpc_id" {
  description = "VPC the private DNS namespace is associated with."
  type        = string
}

variable "execution_role_arn" {
  description = "Role the ECS agent assumes to pull the image and write logs."
  type        = string
}

variable "task_role_arn" {
  description = "Role the application assumes."
  type        = string
}

variable "repository_url" {
  description = "ECR registry path."
  type        = string
}

variable "initial_image_tag" {
  description = <<-EOT
    Tag Terraform writes into its own revision of the task definition. The app
    pipeline overwrites it on every deployment, so this value matters only for
    the first task that starts.
  EOT
  type        = string
  default     = "main"
}

variable "log_group_name" {
  description = "CloudWatch log group the container writes to."
  type        = string
}

variable "app_port" {
  description = "Port the container listens on."
  type        = number
  default     = 8080
}

variable "task_cpu" {
  description = "Fargate CPU units. 256 is a quarter vCPU, the smallest Fargate size."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate memory in MiB."
  type        = number
  default     = 512
}
