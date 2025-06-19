provider "aws" {
  region = var.aws_region
}

# Local variables
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# S3 Module
module "s3" {
  source = "./modules/s3"
  
  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# DynamoDB Module
module "dynamodb" {
  source = "./modules/dynamodb"
  
  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# IAM Module
module "iam" {
  source = "./modules/iam"
  
  project_name              = var.project_name
  environment               = var.environment
  aws_region               = var.aws_region
  model_artifacts_bucket_arn = module.s3.model_artifacts_bucket_arn
  prediction_log_table_arn   = module.dynamodb.prediction_log_table_arn
  endpoint_name             = var.endpoint_name
  tags                      = local.common_tags
}


# SageMaker Module
module "sagemaker" {
  source = "./modules/sagemaker"
  
  project_name               = var.project_name
  environment                = var.environment
  aws_region                = var.aws_region
  model_name                = var.model_name
  endpoint_name             = var.endpoint_name
  instance_type             = var.instance_type
  min_instances             = var.min_instances
  max_instances             = var.max_instances
  sagemaker_execution_role_arn = module.iam.sagemaker_execution_role_arn
  model_artifact_s3_uri     = module.s3.model_artifacts_bucket_object_uri
  model_artifacts_bucket_name = module.s3.model_artifacts_bucket_name
  auto_scaling_role_arn     = module.iam.auto_scaling_role_arn
  tags                      = local.common_tags
  depends_on = [module.s3]
}

# use the following commented code to enable the Lambda and API Gateway modules if needed
# # Lambda Module
# module "lambda" {
#   source = "./modules/lambda"
  
#   project_name          = var.project_name
#   environment           = var.environment
#   lambda_execution_role_arn = module.iam.lambda_execution_role_arn
#   endpoint_name         = module.sagemaker.endpoint_name
#   dynamodb_table_name   = module.dynamodb.prediction_log_table_name
#   tags                  = local.common_tags
# }

# # API Gateway Module
# module "api_gateway" {
#   source = "./modules/api_gateway"
  
#   project_name     = var.project_name
#   environment      = var.environment
#   aws_region       = var.aws_region
#   lambda_function_arn = module.lambda.lambda_function_arn
#   lambda_function_name = module.lambda.lambda_function_name
#   tags             = local.common_tags
#   depends_on = [module.lambda]
# }

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"
  
  project_name          = var.project_name
  environment           = var.environment
  aws_region           = var.aws_region
  alert_email          = var.alert_email
  endpoint_name        = module.sagemaker.endpoint_name
#  lambda_function_name = module.lambda.lambda_function_name
  tags                 = local.common_tags
}

# SSM Parameters Module
module "ssm_parameters" {
  source = "./modules/ssm_parameters"
  
  project_name               = var.project_name
  endpoint_name             = module.sagemaker.endpoint_name
  model_name                = module.sagemaker.model_name
  s3_bucket_name            = module.s3.model_artifacts_bucket_name
  dynamodb_table_name       = module.dynamodb.prediction_log_table_name
  sns_topic_arn             = module.monitoring.sns_topic_arn
}