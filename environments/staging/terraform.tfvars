# AWS Configuration
region = "us-east-1"

# EKS Cluster Configuration
cluster_name       = "retail-store-staging"
kubernetes_version = "1.32"

# Network Configuration
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.20.0/24"]
single_nat_gateway   = false

# EKS API Access
endpoint_public_access = false
public_access_cidrs    = []

# Node Group Configuration
instance_types = ["t3.large"]
desired_size   = 3
max_size       = 6
min_size       = 2
disk_size      = 30
capacity_type  = "ON_DEMAND"

# Database Configuration
postgresql_username = "postgres"
postgresql_password = "staging-postgres-secure123!"
mysql_username      = "admin"
mysql_password      = "staging-mysql-secure123!"
redis_auth_token    = "staging-redis-secure-token123"

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
}