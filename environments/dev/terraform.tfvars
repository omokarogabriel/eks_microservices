# AWS Configuration
region = "us-east-1"

# EKS Cluster Configuration
cluster_name       = "retail-store-dev"
kubernetes_version = "1.32"

# Network Configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
single_nat_gateway   = true

# EKS API Access
endpoint_public_access = true
public_access_cidrs    = []

# Node Group Configuration
instance_types = ["t3.medium"]
desired_size   = 2
max_size       = 4
min_size       = 1
disk_size      = 20
capacity_type  = "ON_DEMAND" # Options: ON_DEMAND or SPOT

# Database Configuration
postgresql_username = "postgres"
postgresql_password = "postgres123!"
mysql_username      = "admin"
mysql_password      = "mysql123!"
redis_auth_token    = "redis123token"

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
}