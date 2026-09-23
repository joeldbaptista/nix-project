variable "project" {
  description = "Name prefix for every resource."
  type        = string
}

variable "keep_image_count" {
  description = "Number of tagged images to retain."
  type        = number
  default     = 10
}
