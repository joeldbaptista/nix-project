variable "project" {
  description = "Name prefix for every resource."
  type        = string
}

variable "region" {
  description = "Region, needed to compose endpoint service names."
  type        = string
}

variable "vpc_id" {
  description = "VPC the endpoints are created in."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets available to hold endpoint network interfaces."
  type        = list(string)
}

variable "endpoints_sg_id" {
  description = "Security group applied to the endpoint network interfaces."
  type        = string
}

variable "single_az" {
  description = <<-EOT
    Place the endpoints in one availability zone only. Each endpoint is billed
    per zone, so true roughly halves the cost. Set it to false for a
    production-shaped deployment, where a zone failure must not take the
    endpoints with it.
  EOT
  type        = bool
  default     = true
}
