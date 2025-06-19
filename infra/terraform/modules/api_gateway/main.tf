resource "aws_api_gateway_rest_api" "fraud_detection" {
  name        = "${var.project_name}-api-${var.environment}"
  description = "Fraud Detection API Gateway"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "*"
      }
    ]
  })

  tags = var.tags
}

# API Gateway Resource
resource "aws_api_gateway_resource" "predict" {
  rest_api_id = aws_api_gateway_rest_api.fraud_detection.id
  parent_id   = aws_api_gateway_rest_api.fraud_detection.root_resource_id
  path_part   = "predict"
}

# API Gateway Method
resource "aws_api_gateway_method" "predict_post" {
  rest_api_id   = aws_api_gateway_rest_api.fraud_detection.id
  resource_id   = aws_api_gateway_resource.predict.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Integration
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.fraud_detection.id
  resource_id = aws_api_gateway_resource.predict.id
  http_method = aws_api_gateway_method.predict_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = var.lambda_function_invoke_arn
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.fraud_detection.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "fraud_detection" {
  depends_on = [
    aws_api_gateway_integration.lambda
  ]

  rest_api_id = aws_api_gateway_rest_api.fraud_detection.id
  
  lifecycle {
    create_before_destroy = true
  }
  
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.predict.id,
      aws_api_gateway_method.predict_post.id,
      aws_api_gateway_integration.lambda.id,
    ]))
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.fraud_detection.id
  rest_api_id   = aws_api_gateway_rest_api.fraud_detection.id
  stage_name    = "prod"
  
  tags = var.tags
}

# CORS configuration for OPTIONS method
resource "aws_api_gateway_method" "predict_options" {
  rest_api_id   = aws_api_gateway_rest_api.fraud_detection.id
  resource_id   = aws_api_gateway_resource.predict.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id = aws_api_gateway_rest_api.fraud_detection.id
  resource_id = aws_api_gateway_resource.predict.id
  http_method = aws_api_gateway_method.predict_options.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options" {
  rest_api_id = aws_api_gateway_rest_api.fraud_detection.id
  resource_id = aws_api_gateway_resource.predict.id
  http_method = aws_api_gateway_method.predict_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  rest_api_id = aws_api_gateway_rest_api.fraud_detection.id
  resource_id = aws_api_gateway_resource.predict.id
  http_method = aws_api_gateway_method.predict_options.http_method
  status_code = aws_api_gateway_method_response.options.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}
