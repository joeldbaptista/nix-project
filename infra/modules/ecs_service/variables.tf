variable "cluster_arn" {
  description = "Cluster the service runs on."
  type        = string
}

variable "task_definition_arn" {
  description = "Revision the service starts from. Later revisions come from the app pipeline."
  type        = string
}

variable "namespace_id" {
  description = "Cloud Map private DNS namespace to register in."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets the tasks run in."
  type        = list(string)
}

variable "tasks_sg_id" {
  description = "Security group applied to the task network interfaces."
  type        = string
}

variable "desired_count" {
  description = "Number of tasks to run. Set to 0 to park the service without destroying it."
  type        = number
  default     = 1
}

variable "wait_for_steady_state" {
  description = <<-EOT
    Block the apply until the service reaches a steady state. It makes a broken
    deployment fail the pipeline instead of succeeding quietly, at the cost of
    a slower apply.
  EOT
  type        = bool
  default     = true
}
