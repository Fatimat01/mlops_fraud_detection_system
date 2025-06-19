# modules/ssm_parameters/main.tf

resource "aws_ssm_parameter" "endpoint_name" {
  name        = "/${var.project_name}/endpoint-name"
  description = "SageMaker endpoint name"
  type        = "String"
  value       = var.endpoint_name
}

resource "aws_ssm_parameter" "model_name" {
  name        = "/${var.project_name}/model-name"
  description = "SageMaker model name"
  type        = "String"
  value       = var.model_name
}

resource "aws_ssm_parameter" "s3_bucket" {
  name        = "/${var.project_name}/s3-bucket"
  description = "S3 bucket for model artifacts"
  type        = "String"
  value       = var.s3_bucket_name
}

resource "aws_ssm_parameter" "dynamodb_table" {
  name        = "/${var.project_name}/dynamodb-table"
  description = "DynamoDB table for predictions"
  type        = "String"
  value       = var.dynamodb_table_name
}

resource "aws_ssm_parameter" "sns_topic" {
  name        = "/${var.project_name}/sns-topic"
  description = "SNS topic for alerts"
  type        = "String"
  value       = var.sns_topic_arn
}



