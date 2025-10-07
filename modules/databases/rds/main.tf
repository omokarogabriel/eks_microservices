resource "aws_db_subnet_group" "this" {
  name       = "${var.cluster_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-db-subnet-group"
  })
}

resource "aws_db_parameter_group" "postgresql" {
  count  = var.create_postgresql ? 1 : 0
  family = "postgres15"
  name   = "${var.cluster_name}-postgresql-params"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  tags = var.common_tags
}

resource "aws_db_parameter_group" "mysql" {
  count  = var.create_mysql ? 1 : 0
  family = "mysql8.0"
  name   = "${var.cluster_name}-mysql-params"

  parameter {
    name  = "general_log"
    value = "1"
  }

  tags = var.common_tags
}

resource "aws_db_instance" "postgresql" {
  count = var.create_postgresql ? 1 : 0

  identifier     = "${var.cluster_name}-postgresql"
  engine         = "postgres"
  engine_version = "15.7"
  instance_class = var.postgresql_instance_class

  allocated_storage     = var.postgresql_allocated_storage
  max_allocated_storage = var.postgresql_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name  = var.postgresql_db_name
  username = var.postgresql_username
  password = var.postgresql_password

  vpc_security_group_ids = [var.database_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.this.name
  parameter_group_name   = aws_db_parameter_group.postgresql[0].name

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot = var.environment == "dev"
  deletion_protection = var.environment == "prod"

  tags = merge(var.common_tags, {
    Name   = "${var.cluster_name}-postgresql"
    Engine = "postgresql"
  })
}

resource "aws_db_instance" "mysql" {
  count = var.create_mysql ? 1 : 0

  identifier     = "${var.cluster_name}-mysql"
  engine         = "mysql"
  engine_version = "8.0.39"
  instance_class = var.mysql_instance_class

  allocated_storage     = var.mysql_allocated_storage
  max_allocated_storage = var.mysql_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name  = var.mysql_db_name
  username = var.mysql_username
  password = var.mysql_password

  vpc_security_group_ids = [var.database_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.this.name
  parameter_group_name   = aws_db_parameter_group.mysql[0].name

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot = var.environment == "dev"
  deletion_protection = var.environment == "prod"

  tags = merge(var.common_tags, {
    Name   = "${var.cluster_name}-mysql"
    Engine = "mysql"
  })
}