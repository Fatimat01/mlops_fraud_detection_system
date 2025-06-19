# variables.tf

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "fraud-detection"
}

variable "environment" {
  description = "Environment type"
  type        = string
  default     = "prod"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "endpoint_name" {
  description = "SageMaker endpoint name"
  type        = string
  default     = "fraud-detection-endpoint"
}

variable "model_name" {
  description = "SageMaker model name"
  type        = string
  default     = "fraud-detection-model"
}

variable "alert_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
  
  validation {
    condition     = can(regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", var.alert_email))
    error_message = "Alert email must be a valid email address."
  }
}

variable "instance_type" {
  description = "SageMaker instance type"
  type        = string
  default     = "ml.t2.medium"
  
  validation {
    condition = contains([
      "ml.t2.medium",
      "ml.m5.large"
    #   "ml.m5.xlarge",
    #   "ml.m5.2xlarge",
    #   "ml.m5.4xlarge"
    ], var.instance_type)
    error_message = "Instance type must be one of the allowed values."
  }
}

variable "min_instances" {
  description = "Minimum number of instances for auto-scaling"
  type        = number
  default     = 1
  
  validation {
    condition     = var.min_instances >= 1 && var.min_instances <= 10
    error_message = "Min instances must be between 1 and 10."
  }
}

variable "max_instances" {
  description = "Maximum number of instances for auto-scaling"
  type        = number
  default     = 3
  
  validation {
    condition     = var.max_instances >= 1 && var.max_instances <= 20
    error_message = "Max instances must be between 1 and 20."
  }
}

variable "model_artifact_s3_uri" {
  description = "S3 URI for model artifacts (leave empty to use default bucket)"
  type        = string
  default     = ""
}

