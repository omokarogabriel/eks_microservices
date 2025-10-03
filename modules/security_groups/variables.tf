variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name)) && length(var.cluster_name) <= 100
    error_message = "Cluster name must start with a letter, contain only alphanumeric characters and hyphens, and be <= 100 characters."
  }
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must be a valid AWS VPC ID starting with 'vpc-'."
  }
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_alb_security_group" {
  description = "Whether to create ALB security group"
  type        = bool
  default     = true
}