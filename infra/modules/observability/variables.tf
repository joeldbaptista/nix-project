variable "project" {
  description = "Name prefix for every resource."
  type        = string
}

variable "retention_days" {
  description = "How long container logs are kept."
  type        = number
  default     = 7
}
