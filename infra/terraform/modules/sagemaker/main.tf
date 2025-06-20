# modules/sagemaker/main.tf

data "aws_caller_identity" "current" {}

# SageMaker Model
resource "aws_sagemaker_model" "fraud_detection" {
  name               = "${var.model_name}-${var.environment}"
  execution_role_arn = var.sagemaker_execution_role_arn

  primary_container {
    image          = "${data.aws_caller_identity.current.id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}:latest"
    model_data_url = var.model_artifact_s3_uri
    
    # environment = {
    #   SAGEMAKER_PROGRAM          = "inference.py"
    #   SAGEMAKER_SUBMIT_DIRECTORY = var.model_artifact_s3_uri
    # }
  }

  tags = merge(var.tags, {
    Name = "${var.model_name}-${var.environment}"
  })
}

# SageMaker Endpoint Configuration
resource "aws_sagemaker_endpoint_configuration" "fraud_detection" {
  name = "${var.endpoint_name}-config-${var.environment}"

  production_variants {
    variant_name           = "AllTraffic"
    model_name            = aws_sagemaker_model.fraud_detection.name
    initial_instance_count = var.min_instances
    instance_type         = var.instance_type
    initial_variant_weight = 1
  }

  data_capture_config {
    enable_capture              = true
    initial_sampling_percentage = 100
    destination_s3_uri         = "s3://${var.model_artifacts_bucket_name}/data-capture/"
    
    capture_options {
      capture_mode = "Input"
    }
    
    capture_options {
      capture_mode = "Output"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.endpoint_name}-config-${var.environment}"
  })
}

# SageMaker Endpoint
resource "aws_sagemaker_endpoint" "fraud_detection" {
  name                 = var.endpoint_name
  endpoint_config_name = aws_sagemaker_endpoint_configuration.fraud_detection.name

  tags = merge(var.tags, {
    Name = var.endpoint_name
  })
}

# Auto Scaling Target
# resource "aws_appautoscaling_target" "sagemaker_endpoint" {
#   service_namespace  = "sagemaker"
#   resource_id        = "endpoint/${aws_sagemaker_endpoint.fraud_detection.name}/variant/AllTraffic"
#   scalable_dimension = "sagemaker:variant:DesiredInstanceCount"
#   min_capacity       = var.min_instances
#   max_capacity       = var.max_instances
#   role_arn          = var.auto_scaling_role_arn
# }

# # Auto Scaling Policy
# resource "aws_appautoscaling_policy" "sagemaker_endpoint" {
#   name               = "${var.endpoint_name}-scaling-policy"
#   policy_type        = "TargetTrackingScaling"
#   service_namespace  = aws_appautoscaling_target.sagemaker_endpoint.service_namespace
#   resource_id        = aws_appautoscaling_target.sagemaker_endpoint.resource_id
#   scalable_dimension = aws_appautoscaling_target.sagemaker_endpoint.scalable_dimension

#   target_tracking_scaling_policy_configuration {
#     target_value = 70.0

#     predefined_metric_specification {
#       predefined_metric_type = "SageMakerVariantInvocationsPerInstance"
#     }

#     scale_in_cooldown  = 300
#     scale_out_cooldown = 60
#   }
# }


