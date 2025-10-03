variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for cost optimization"
  type        = bool
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
}

variable "instance_types" {
  description = "List of instance types for the node group"
  type        = list(string)
}

variable "desired_size" {
  description = "Desired number of worker nodes"
  type        = number
}

variable "max_size" {
  description = "Maximum number of worker nodes"
  type        = number
}

variable "min_size" {
  description = "Minimum number of worker nodes"
  type        = number
}

variable "disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
}

variable "capacity_type" {
  description = "Type of capacity associated with the EKS Node Group"
  type        = string
}

variable "postgresql_username" {
  description = "Username for PostgreSQL database"
  type        = string
}

variable "postgresql_password" {
  description = "Password for PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "mysql_username" {
  description = "Username for MySQL database"
  type        = string
}

variable "mysql_password" {
  description = "Password for MySQL database"
  type        = string
  sensitive   = true
}

variable "redis_auth_token" {
  description = "Auth token for Redis"
  type        = string
  sensitive   = true
}

variable "dynamodb_tables" {
  description = "Map of DynamoDB tables to create"
  type = map(object({
    billing_mode   = string
    hash_key       = string
    range_key      = optional(string)
    read_capacity  = optional(number)
    write_capacity = optional(number)
    attributes = list(object({
      name = string
      type = string
    }))
    global_secondary_indexes = optional(list(object({
      name            = string
      hash_key        = string
      range_key       = optional(string)
      projection_type = string
      read_capacity   = optional(number)
      write_capacity  = optional(number)
    })), [])
  }))
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}