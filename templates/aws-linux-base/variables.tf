variable "aws_region" {
  description = "The AWS region to deploy the workspace in"
  default     = "us-east-1"
  type        = string
}

variable "instance_type" {
  description = "The AWS instance type to use for the workspace"
  default     = "t3.medium"
  type        = string
  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium", "t3.large", "t3.xlarge"], var.instance_type)
    error_message = "The instance_type must be one of: t3.micro, t3.small, t3.medium, t3.large, t3.xlarge"
  }
}

variable "disk_size" {
  description = "The size of the root disk in GiB"
  default     = 30
  type        = number
  validation {
    condition     = var.disk_size >= 20 && var.disk_size <= 100
    error_message = "The disk_size must be between 20 and 100 GiB"
  }
}

variable "public_key" {
  description = "The public SSH key to use for the workspace"
  default     = ""
  type        = string
}
