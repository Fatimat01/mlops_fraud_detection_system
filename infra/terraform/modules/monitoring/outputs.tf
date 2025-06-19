output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.monitoring.dashboard_name}"
}

output "high_latency_alarm_name" {
  description = "Name of the high latency alarm"
  value       = aws_cloudwatch_metric_alarm.high_latency.alarm_name
}

output "high_error_rate_alarm_name" {
  description = "Name of the high error rate alarm"
  value       = aws_cloudwatch_metric_alarm.high_error_rate.alarm_name
}

output "endpoint_failure_alarm_name" {
  description = "Name of the endpoint failure alarm"
  value       = aws_cloudwatch_metric_alarm.endpoint_failure.alarm_name
}