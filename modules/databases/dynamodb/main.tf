resource "aws_dynamodb_table" "microservices_tables" {
  for_each = var.dynamodb_tables

  name         = "${var.cluster_name}-${each.key}"
  billing_mode = each.value.billing_mode
  hash_key     = each.value.hash_key
  range_key    = each.value.range_key

  read_capacity  = each.value.billing_mode == "PROVISIONED" ? each.value.read_capacity : null
  write_capacity = each.value.billing_mode == "PROVISIONED" ? each.value.write_capacity : null

  dynamic "attribute" {
    for_each = each.value.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "global_secondary_index" {
    for_each = each.value.global_secondary_indexes
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = global_secondary_index.value.range_key
      projection_type = global_secondary_index.value.projection_type

      read_capacity  = each.value.billing_mode == "PROVISIONED" ? global_secondary_index.value.read_capacity : null
      write_capacity = each.value.billing_mode == "PROVISIONED" ? global_secondary_index.value.write_capacity : null
    }
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.environment == "prod"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.cluster_name}-${each.key}"
    TableName   = each.key
    Environment = var.environment
  })
}