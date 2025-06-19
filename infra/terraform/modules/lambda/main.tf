




# Create ZIP file for Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  
  source {
    content  = "${path.module}/lambda_function.py"
    filename = "index.py"
  }
}

# Lambda Function
resource "aws_lambda_function" "prediction" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-prediction-lambda-${var.environment}"
  role            = var.lambda_execution_role_arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 30
  memory_size     = 512

  environment {
    variables = {
      ENDPOINT_NAME  = var.endpoint_name
      DYNAMODB_TABLE = var.dynamodb_table_name
      PROJECT_NAME   = var.project_name
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-prediction-lambda-${var.environment}"
  })
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.prediction.function_name}"
  retention_in_days = 14

  tags = var.tags
}



