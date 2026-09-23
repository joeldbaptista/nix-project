variable "project" {
  description = "Name prefix for every resource."
  type        = string
}

variable "iam_path" {
  description = "IAM path, which must match the path the apply role is scoped to."
  type        = string
  default     = "/fortune/"
}

variable "subnet_id" {
  description = "Public subnet the instance runs in."
  type        = string
}

variable "bastion_sg_id" {
  description = "Security group with no inbound rules and outbound HTTPS."
  type        = string
}

variable "instance_type" {
  description = "Graviton nano is the cheapest instance that runs the SSM agent comfortably."
  type        = string
  default     = "t4g.nano"
}

variable "root_volume_size" {
  description = "Root volume size in GiB."
  type        = number
  default     = 8
}
