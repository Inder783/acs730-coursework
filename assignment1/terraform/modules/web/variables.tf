variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging or prod."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the environment VPC."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "Provide a valid IPv4 CIDR block."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the web server."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "Use t3.micro or t3.small to control costs."
  }
}

variable "app_version" {
  description = "Application version promoted between environments."
  type        = string
  default     = "v1"

  validation {
    condition     = can(regex("^v[0-9]+$", var.app_version))
    error_message = "Application version must follow the format v1, v2, etc."
  }
}
