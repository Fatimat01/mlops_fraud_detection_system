
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

variable "lambda_function_arn" {
  description = "ARN of the Lambda function"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_function_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}