resource "aws_secretsmanager_secret" "database_secrets" {
  for_each = var.database_secrets

  name                    = "${var.cluster_name}-${each.key}-credentials"
  description             = "Database credentials for ${each.key}"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.common_tags, {
    Name     = "${var.cluster_name}-${each.key}-credentials"
    Type     = "database-secret"
    Database = each.key
  })
}

resource "aws_secretsmanager_secret_version" "database_secrets" {
  for_each = var.database_secrets

  secret_id = aws_secretsmanager_secret.database_secrets[each.key].id
  secret_string = jsonencode({
    username = each.value.username
    password = each.value.password
    engine   = each.value.engine
    host     = each.value.host
    port     = each.value.port
    dbname   = each.value.dbname
  })
}