
output "sagemaker_execution_role_arn" {
  description = "ARN of the SageMaker execution role"
  value       = aws_iam_role.sagemaker_execution.arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "auto_scaling_role_arn" {
  description = "ARN of the auto scaling role"
  value       = aws_iam_role.auto_scaling.arn
}