variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  type        = string
}

variable "endpoint_name" {
  description = "SageMaker endpoint name"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

