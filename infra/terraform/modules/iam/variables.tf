variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "model_artifacts_bucket_arn" {
  description = "ARN of the model artifacts bucket"
  type        = string
}

variable "prediction_log_table_arn" {
  description = "ARN of the prediction log table"
  type        = string
}

variable "endpoint_name" {
  description = "SageMaker endpoint name"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

