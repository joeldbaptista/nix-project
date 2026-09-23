variable "project" {
  description = "Name prefix for every resource."
  type        = string
}

variable "region" {
  description = "Region, needed to compose endpoint service names."
  type        = string
}

variable "vpc_cidr" {
  description = "Address range of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across."
  type        = number
  default     = 2
}
