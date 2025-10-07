# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

# EKS Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

# Database Outputs
output "postgresql_endpoint" {
  description = "RDS PostgreSQL instance endpoint"
  value       = module.rds.postgresql_endpoint
  sensitive   = true
}

output "mysql_endpoint" {
  description = "RDS MySQL instance endpoint"
  value       = module.rds.mysql_endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.elasticache.redis_endpoint
  sensitive   = true
}

output "dynamodb_table_names" {
  description = "Names of the DynamoDB tables"
  value       = module.dynamodb.table_names
}

# GitHub Actions Output
output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = module.github_actions.github_actions_role_arn
}

# Readonly User Output
output "readonly_user_credentials" {
  description = "Readonly user access credentials"
  value = {
    user_name         = module.readonly_user.user_name
    user_arn          = module.readonly_user.user_arn
    access_key_id     = module.readonly_user.access_key_id
    secret_access_key = module.readonly_user.secret_access_key
  }
  sensitive   = true
}

# AWS Auth ConfigMap
output "aws_auth_configmap" {
  description = "AWS auth ConfigMap for kubectl access"
  value = {
    configmap_name      = module.aws_auth.configmap_name
    configmap_namespace = module.aws_auth.configmap_namespace
  }
}

# IRSA Role ARNs
output "cart_service_role_arn" {
  description = "ARN of the cart service IAM role"
  value       = module.irsa_roles.cart_service_role_arn
}

output "catalog_service_role_arn" {
  description = "ARN of the catalog service IAM role"
  value       = module.irsa_roles.catalog_service_role_arn
}

output "order_service_role_arn" {
  description = "ARN of the order service IAM role"
  value       = module.irsa_roles.order_service_role_arn
}

output "checkout_service_role_arn" {
  description = "ARN of the checkout service IAM role"
  value       = module.irsa_roles.checkout_service_role_arn
}