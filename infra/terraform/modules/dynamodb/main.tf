# modules/dynamodb/main.tf

resource "aws_dynamodb_table" "prediction_log" {
  name           = "${var.project_name}-predictions"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "prediction_id"
  range_key      = "timestamp"
  
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "prediction_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "request_id"
    type = "S"
  }

  global_secondary_index {
    name            = "RequestIdIndex"
    hash_key        = "request_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-predictions"
  })
}


