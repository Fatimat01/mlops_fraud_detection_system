

# modules/api_gateway/outputs.tf

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/predict"
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.fraud_detection.id
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.fraud_detection.execution_arn
}