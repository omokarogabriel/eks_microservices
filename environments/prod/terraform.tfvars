# AWS Configuration
region = "us-east-1"

# EKS Cluster Configuration
# cluster_name       = "prod-eks-cluster"
cluster_name       = "retail-store-prod"
kubernetes_version = "1.28"

# Network Configuration
vpc_cidr             = "10.2.0.0/16"
public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
private_subnet_cidrs = ["10.2.10.0/24", "10.2.20.0/24", "10.2.30.0/24"]
single_nat_gateway   = false

# EKS API Access
endpoint_public_access = false
public_access_cidrs    = []

# Node Group Configuration
instance_types = ["t3.xlarge"]
desired_size   = 6
max_size       = 12
min_size       = 3
disk_size      = 50
capacity_type  = "ON_DEMAND"

# Database Configuration
postgresql_username = "postgres"
postgresql_password = "prod-postgres-ultra-secure-2024!"
mysql_username      = "admin"
mysql_password      = "prod-mysql-ultra-secure-2024!"
redis_auth_token    = "prod-redis-ultra-secure-token-2024"

# GitHub Actions Configuration
github_org  = "omokarogabriel"
github_repo = "eks_microservices"

# DynamoDB Configuration
dynamodb_tables = {
  carts = {
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "cart_id"
    attributes = [
      {
        name = "cart_id"
        type = "S"
      }
    ]
  }
  orders = {
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "order_id"
    attributes = [
      {
        name = "order_id"
        type = "S"
      }
    ]
  }
  products = {
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "product_id"
    attributes = [
      {
        name = "product_id"
        type = "S"
      }
    ]
  }
}