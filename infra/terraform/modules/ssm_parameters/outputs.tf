output "parameter_names" {
  description = "Map of parameter names"
  value = {
    endpoint_name      = aws_ssm_parameter.endpoint_name.name
    model_name        = aws_ssm_parameter.model_name.name
    s3_bucket         = aws_ssm_parameter.s3_bucket.name
    dynamodb_table    = aws_ssm_parameter.dynamodb_table.name
    sns_topic         = aws_ssm_parameter.sns_topic.name
  }
}