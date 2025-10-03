variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

