variable "project" {
  description = "Name prefix for every resource."
  type        = string
}

variable "vpc_id" {
  description = "VPC the groups belong to."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC address range, used for the DNS resolver egress rules."
  type        = string
}

variable "app_port" {
  description = "Port the container listens on."
  type        = number
  default     = 8080
}
