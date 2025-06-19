# modules/monitoring/main.tf

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name         = "${var.project_name}-alerts-${var.environment}"
  display_name = "${var.project_name} Fraud Detection Alerts"
  
  tags = var.tags
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "alert_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Log Group for SageMaker
resource "aws_cloudwatch_log_group" "sagemaker" {
  name              = "/aws/sagemaker/Endpoints/${var.endpoint_name}"
  retention_in_days = 30
  
  tags = var.tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "monitoring" {
  dashboard_name = "${var.project_name}-dashboard-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/SageMaker", "Invocations", "EndpointName", var.endpoint_name, "VariantName", "AllTraffic"],
            [".", "InvocationsPerInstance", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Endpoint Invocations"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/SageMaker", "ModelLatency", "EndpointName", var.endpoint_name, "VariantName", "AllTraffic"],
            [".", "OverheadLatency", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Latency Metrics"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/SageMaker", "ModelInvocation4XXErrors", "EndpointName", var.endpoint_name, "VariantName", "AllTraffic"],
            [".", "ModelInvocation5XXErrors", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Errors"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/SageMaker", "CPUUtilization", "EndpointName", var.endpoint_name, "VariantName", "AllTraffic"],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Resource Utilization"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      # {
      #   type   = "metric"
      #   x      = 0
      #   y      = 12
      #   width  = 24
      #   height = 6
      #   properties = {
      #     metrics = [
      #       ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name],
      #       [".", "Invocations", ".", "."],
      #       [".", "Errors", ".", "."]
      #     ]
      #     period = 300
      #     stat   = "Average"
      #     region = var.aws_region
      #     title  = "Lambda Performance"
      #   }
      # }
    ]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "${var.project_name}-HighLatency-${var.environment}"
  alarm_description   = "Alert when model latency is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ModelLatency"
  namespace           = "AWS/SageMaker"
  period              = 300
  statistic           = "Average"
  threshold           = 1000
  treat_missing_data  = "notBreaching"

  dimensions = {
    EndpointName = var.endpoint_name
    VariantName  = "AllTraffic"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.project_name}-HighErrorRate-${var.environment}"
  alarm_description   = "Alert when error rate is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ModelInvocation4XXErrors"
  namespace           = "AWS/SageMaker"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  dimensions = {
    EndpointName = var.endpoint_name
    VariantName  = "AllTraffic"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "endpoint_failure" {
  alarm_name          = "${var.project_name}-EndpointFailure-${var.environment}"
  alarm_description   = "Alert when endpoint is not receiving invocations"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Invocations"
  namespace           = "AWS/SageMaker"
  period              = 600
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    EndpointName = var.endpoint_name
    VariantName  = "AllTraffic"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  
  tags = var.tags
}





