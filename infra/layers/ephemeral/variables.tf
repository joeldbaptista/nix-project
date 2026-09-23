variable "region" {
  description = "AWS region. Must match the durable layer's region."
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Name prefix for every resource."
  type        = string
  default     = "fortune"
}

variable "state_bucket" {
  description = <<-EOT
    Bucket holding the durable layer's state. It contains the account ID, so it
    has no default and is supplied by the workflow or by terraform.tfvars.
  EOT
  type        = string
}

variable "single_az_endpoints" {
  description = "Place interface endpoints in one availability zone, halving their cost."
  type        = bool
  default     = true
}

variable "desired_count" {
  description = "Number of tasks to run."
  type        = number
  default     = 1
}

variable "bastion_instance_type" {
  description = "Instance type for the bastion."
  type        = string
  default     = "t4g.nano"
}
