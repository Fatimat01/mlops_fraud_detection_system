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

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
}

variable "endpoint_name" {
  description = "SageMaker endpoint name"
  type        = string
}

# variable "lambda_function_name" {
#   description = "Lambda function name"
#   type        = string
# }

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}