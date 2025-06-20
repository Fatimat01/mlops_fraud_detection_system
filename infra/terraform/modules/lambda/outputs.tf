
output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.prediction.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.prediction.function_name
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.prediction.invoke_arn
}