# modules/iam/main.tf

data "aws_caller_identity" "current" {}

# SageMaker Execution Role
resource "aws_iam_role" "sagemaker_execution" {
  name = "${var.project_name}-sagemaker-role-${var.aws_region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy" "s3_model_artifact_access" {
  name = "S3ModelArtifactAccess"
  role = aws_iam_role.sagemaker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${var.model_artifacts_bucket_arn}/*",
          var.model_artifacts_bucket_arn
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = "arn:aws:s3:::sagemaker-${var.aws_region}-${data.aws_caller_identity.current.account_id}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudwatch_logs_access" {
  name = "CloudWatchLogsAccess"
  role = aws_iam_role.sagemaker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/sagemaker/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecr_access" {
  name = "ECRAccess"
  role = aws_iam_role.sagemaker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda Execution Role
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-role-${var.aws_region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "sagemaker_invoke_endpoint" {
  name = "SageMakerInvokeEndpoint"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["sagemaker:InvokeEndpoint"]
        Resource = "arn:aws:sagemaker:${var.aws_region}:${data.aws_caller_identity.current.account_id}:endpoint/${var.endpoint_name}"
      }
    ]
  })
}

resource "aws_iam_role_policy" "dynamodb_access" {
  name = "DynamoDBAccess"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          var.prediction_log_table_arn,
          "${var.prediction_log_table_arn}/index/*"
        ]
      }
    ]
  })
}

# Application Auto Scaling Service Role
resource "aws_iam_role" "auto_scaling" {
  name = "application-autoscaling-sagemaker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "application-autoscaling.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "sagemaker_auto_scaling" {
  name = "SageMakerAutoScalingPolicy"
  role = aws_iam_role.auto_scaling.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:DescribeEndpoint",
          "sagemaker:DescribeEndpointConfig",
          "sagemaker:UpdateEndpointWeightsAndCapacities"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      }
    ]
  })
}


