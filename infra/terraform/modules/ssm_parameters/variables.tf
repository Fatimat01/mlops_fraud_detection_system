
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "endpoint_name" {
  description = "SageMaker endpoint name"
  type        = string
}

variable "model_name" {
  description = "SageMaker model name"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN"
  type        = string
}
