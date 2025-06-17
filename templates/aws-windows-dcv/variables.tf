variable "aws_region" {
  description = "The AWS region to deploy the workspace in"
  default     = "us-east-1"
  type        = string
}

variable "instance_type" {
  description = "The AWS instance type to use for the workspace"
  default     = "t3.large"
  type        = string
  validation {
    condition     = contains(["t3.medium", "t3.large", "t3.xlarge", "t3.2xlarge"], var.instance_type)
    error_message = "The instance_type must be one of: t3.medium, t3.large, t3.xlarge, t3.2xlarge"
  }
}

variable "disk_size" {
  description = "The size of the root disk in GiB"
  default     = 50
  type        = number
  validation {
    condition     = var.disk_size >= 30 && var.disk_size <= 150
    error_message = "The disk_size must be between 30 and 150 GiB"
  }
}
