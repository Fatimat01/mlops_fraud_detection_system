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

variable "model_name" {
  description = "SageMaker model name"
  type        = string
}

variable "endpoint_name" {
  description = "SageMaker endpoint name"
  type        = string
}

variable "instance_type" {
  description = "SageMaker instance type"
  type        = string
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
}

variable "sagemaker_execution_role_arn" {
  description = "ARN of the SageMaker execution role"
  type        = string
}

variable "model_artifact_s3_uri" {
  description = "S3 URI for model artifacts"
  type        = string
}

variable "model_artifacts_bucket_name" {
  description = "Name of the model artifacts bucket"
  type        = string
}

variable "auto_scaling_role_arn" {
  description = "ARN of the auto scaling role"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

