variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name)) && length(var.cluster_name) <= 100
    error_message = "Cluster name must start with a letter, contain only alphanumeric characters and hyphens, and be <= 100 characters."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_ebs_csi_driver" {
  description = "Whether to create EBS CSI driver IAM role"
  type        = bool
  default     = true
}

variable "additional_policies" {
  description = "Additional IAM policies to attach to worker nodes"
  type        = list(string)
  default     = []
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  type        = string
  default     = ""
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider"
  type        = string
  default     = ""
}