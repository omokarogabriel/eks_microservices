resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.cluster_name}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-redis-subnet-group"
  })
}

resource "aws_elasticache_parameter_group" "redis" {
  family = "redis7.x"
  name   = "${var.cluster_name}-redis-params"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = var.common_tags
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.cluster_name}-redis"
  description          = "Redis cluster for ${var.cluster_name}"

  node_type            = var.redis_node_type
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.redis.name

  num_cache_clusters = var.redis_num_cache_nodes
  engine_version     = "7.0"

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [var.redis_security_group_id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token
  kms_key_id                 = var.kms_key_arn

  automatic_failover_enabled = var.redis_num_cache_nodes > 1
  multi_az_enabled           = var.redis_num_cache_nodes > 1

  maintenance_window       = "sun:03:00-sun:04:00"
  snapshot_retention_limit = var.environment == "prod" ? 7 : 1
  snapshot_window          = "02:00-03:00"

  apply_immediately = var.environment == "dev"

  tags = merge(var.common_tags, {
    Name   = "${var.cluster_name}-redis"
    Engine = "redis"
  })
}