# outputs.tf

output "sagemaker_endpoint_name" {
  description = "Name of the deployed SageMaker endpoint"
  value       = module.sagemaker.endpoint_name
}

output "sagemaker_model_name" {
  description = "Name of the SageMaker model"
  value       = module.sagemaker.model_name
}

output "sagemaker_role_arn" {
  description = "SageMaker execution role ARN"
  value       = module.iam.sagemaker_execution_role_arn
}

output "s3_bucket_name" {
  description = "S3 bucket for model artifacts"
  value       = module.s3.model_artifacts_bucket_name
}

output "dynamodb_table_name" {
  description = "DynamoDB table for predictions"
  value       = module.dynamodb.prediction_log_table_name
}

# output "api_gateway_url" {
#   description = "API Gateway URL"
#   value       = module.api_gateway.api_gateway_url
# }

# output "lambda_function_name" {
#   description = "Lambda function name for predictions"
#   value       = module.lambda.lambda_function_name
# }

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = module.monitoring.sns_topic_arn
}

output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = module.monitoring.dashboard_url
}

output "endpoint_url" {
  description = "SageMaker endpoint URL for direct invocation"
  value       = "https://runtime.sagemaker.${var.aws_region}.amazonaws.com/endpoints/${module.sagemaker.endpoint_name}/invocations"
}

output "auto_scaling_configuration" {
  description = "Auto-scaling configuration"
  value       = "Min: ${var.min_instances}, Max: ${var.max_instances}, Target: 70 invocations/instance"
}

output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}