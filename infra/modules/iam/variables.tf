variable "project" {
  description = "Name prefix for every resource."
  type        = string
}

variable "iam_path" {
  description = <<-EOT
    IAM path for these roles. It must match the path the apply role's iam:*
    permission is scoped to, otherwise the infra pipeline cannot create them.
  EOT
  type        = string
  default     = "/fortune/"
}
