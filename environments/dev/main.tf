locals {
  common_tags = {
    # Cost Allocation Tags
    Environment  = "dev"
    Project      = "microservices-eks"
    Owner        = "devops-team"
    CostCenter   = "engineering"
    BusinessUnit = "platform"
    Application  = "kubernetes"

    # Resource Organization Tags
    ManagedBy   = "terraform"
    CreatedDate = "2024-01-15"
    Backup      = "optional"
    Monitoring  = "basic"

    # Operational Tags
    AutoShutdown = "true"
    Schedule     = "business-hours"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr             = var.vpc_cidr
  env_name             = "dev"
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  region               = var.region
  single_nat_gateway   = var.single_nat_gateway
  common_tags          = local.common_tags
}

module "security_groups" {
  source = "../../modules/security_groups"

  cluster_name = var.cluster_name
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = var.vpc_cidr
  common_tags  = local.common_tags
}

module "kms" {
  source = "../../modules/kms"

  cluster_name            = var.cluster_name
  deletion_window_in_days = 7
  common_tags             = local.common_tags
}

module "iam_roles" {
  source = "../../modules/iam_role"

  cluster_name         = var.cluster_name
  enable_ebs_csi_driver = false
  common_tags          = local.common_tags
}

module "rds" {
  source = "../../modules/databases/rds"

  cluster_name               = var.cluster_name
  environment                = "dev"
  private_subnet_ids         = module.vpc.private_subnet_ids
  database_security_group_id = module.security_groups.database_security_group_id
  kms_key_arn                = module.kms.kms_key_arn

  postgresql_username = var.postgresql_username
  postgresql_password = var.postgresql_password
  mysql_username      = var.mysql_username
  mysql_password      = var.mysql_password

  common_tags = local.common_tags
}

module "elasticache" {
  source = "../../modules/databases/elasticache"

  cluster_name            = var.cluster_name
  environment             = "dev"
  private_subnet_ids      = module.vpc.private_subnet_ids
  redis_security_group_id = module.security_groups.redis_security_group_id
  kms_key_arn             = module.kms.kms_key_arn

  redis_auth_token = var.redis_auth_token

  common_tags = local.common_tags
}

module "dynamodb" {
  source = "../../modules/databases/dynamodb"

  cluster_name    = var.cluster_name
  environment     = "dev"
  kms_key_arn     = module.kms.kms_key_arn
  dynamodb_tables = var.dynamodb_tables

  common_tags = local.common_tags
}

module "secrets_manager" {
  source = "../../modules/secrets-manager"

  cluster_name = var.cluster_name
  kms_key_arn  = module.kms.kms_key_arn

  database_secrets = merge(
    module.rds.database_secrets,
    module.elasticache.redis_secret
  )

  common_tags = local.common_tags

  depends_on = [module.rds, module.elasticache]
}

module "github_actions" {
  source = "../../modules/github-actions"

  cluster_name = var.cluster_name
  github_org   = var.github_org
  github_repo  = var.github_repo
  common_tags  = local.common_tags
}

module "readonly_user" {
  source = "../../modules/readonly-user"

  cluster_name = var.cluster_name
  common_tags  = local.common_tags
}

module "aws_auth" {
  source = "../../modules/aws-auth"

  cluster_id    = module.eks.cluster_id
  node_role_arn = module.iam_roles.eks_node_role_arn

  depends_on = [module.eks]
}

module "eks" {
  source = "../../modules/eks"

  cluster_name           = var.cluster_name
  kubernetes_version     = var.kubernetes_version
  private_subnet_ids     = module.vpc.private_subnet_ids
  vpc_id                 = module.vpc.vpc_id
  endpoint_public_access = var.endpoint_public_access
  public_access_cidrs    = var.public_access_cidrs
  instance_types         = var.instance_types
  desired_size           = var.desired_size
  max_size               = var.max_size
  min_size               = var.min_size
  cluster_role_arn       = module.iam_roles.eks_cluster_role_arn
  node_role_arn          = module.iam_roles.eks_node_role_arn
  # ebs_csi_role_arn       = module.iam_roles.eks_ebs_csi_role_arn  # Disabled for now
  kms_key_arn            = module.kms.kms_key_arn
  disk_size              = var.disk_size
  capacity_type          = var.capacity_type
  common_tags            = local.common_tags

  depends_on = [module.iam_roles]
}

module "oidc" {
  source = "../../modules/oidc"

  cluster_name            = var.cluster_name
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  common_tags             = local.common_tags

  depends_on = [module.eks]
}