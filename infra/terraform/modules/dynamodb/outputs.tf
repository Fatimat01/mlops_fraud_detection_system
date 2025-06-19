
output "prediction_log_table_name" {
  description = "Name of the prediction log table"
  value       = aws_dynamodb_table.prediction_log.name
}

output "prediction_log_table_arn" {
  description = "ARN of the prediction log table"
  value       = aws_dynamodb_table.prediction_log.arn
}

output "prediction_log_table_stream_arn" {
  description = "Stream ARN of the prediction log table"
  value       = aws_dynamodb_table.prediction_log.stream_arn
}