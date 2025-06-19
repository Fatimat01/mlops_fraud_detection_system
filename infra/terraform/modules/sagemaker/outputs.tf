
output "model_name" {
  description = "Name of the SageMaker model"
  value       = aws_sagemaker_model.fraud_detection.name
}

output "endpoint_name" {
  description = "Name of the SageMaker endpoint"
  value       = aws_sagemaker_endpoint.fraud_detection.name
}

output "endpoint_arn" {
  description = "ARN of the SageMaker endpoint"
  value       = aws_sagemaker_endpoint.fraud_detection.arn
}

output "endpoint_config_name" {
  description = "Name of the SageMaker endpoint configuration"
  value       = aws_sagemaker_endpoint_configuration.fraud_detection.name
}

# output "endpoint_url" {
#   description = "URL of the SageMaker endpoint"
#   value       = "https://runtime.sagemaker.${var.aws_region}.amazonaws.com/endpoints/${aws_sagemaker_endpoint.fraud_detection.name}"
  
# }