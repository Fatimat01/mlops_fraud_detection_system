# Fraud Detection MLOps Infrastructure - Terraform

This Terraform configuration deploys a complete fraud detection MLOps infrastructure on AWS, including SageMaker endpoints, Lambda functions, API Gateway, DynamoDB, S3, and comprehensive monitoring.

## Architecture Overview

The infrastructure includes:
- **SageMaker**: Model hosting with auto-scaling endpoints
- **Lambda**: Prediction processing and logging
- **API Gateway**: RESTful API for predictions
- **DynamoDB**: Prediction logging with TTL
- **S3**: Model artifact storage with versioning
- **CloudWatch**: Comprehensive monitoring and alerting
- **SNS**: Email alerts for issues
- **SSM Parameters**: Configuration storage

## Directory Structure

```
.
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Variable definitions
├── outputs.tf             # Output definitions
├── terraform.tfvars       # Variable values (create from example)
├── terraform.tfvars.example
└── modules/
    ├── s3/                # S3 bucket for model artifacts
    ├── dynamodb/          # DynamoDB for prediction logging
    ├── iam/               # IAM roles and policies
    ├── sagemaker/         # SageMaker model and endpoint
    ├── lambda/            # Lambda function for predictions
    ├── api_gateway/       # API Gateway configuration
    ├── monitoring/        # CloudWatch and SNS
    └── ssm_parameters/    # SSM parameter store

```

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0
3. An AWS account with appropriate permissions
4. A trained model artifact (or use the default bucket)

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd fraud-detection-terraform
   ```

2. **Create terraform.tfvars**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

4. **Review the plan**
   ```bash
   terraform plan
   ```

5. **Apply the configuration**
   ```bash
   terraform apply
   ```

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `alert_email` | Email for CloudWatch alerts | `admin@example.com` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `us-east-1` |
| `project_name` | Project name for resources | `fraud-detection` |
| `environment` | Environment (dev/staging/prod) | `prod` |
| `endpoint_name` | SageMaker endpoint name | `fraud-detection-endpoint` |
| `model_name` | SageMaker model name | `fraud-detection-model` |
| `instance_type` | SageMaker instance type | `ml.m5.large` |
| `min_instances` | Minimum auto-scaling instances | `1` |
| `max_instances` | Maximum auto-scaling instances | `4` |
| `model_artifact_s3_uri` | S3 URI for model artifacts | `""` (creates new bucket) |

## Usage

### API Endpoint

After deployment, use the API Gateway URL to make predictions:

```bash
curl -X POST https://<api-id>.execute-api.<region>.amazonaws.com/prod/predict \
  -H "Content-Type: application/json" \
  -d '{
    "feature1": 0.5,
    "feature2": 1.2,
    "feature3": -0.8
  }'
```

### Direct SageMaker Invocation

For direct endpoint invocation:

```python
import boto3
import json

client = boto3.client('sagemaker-runtime')
response = client.invoke_endpoint(
    EndpointName='fraud-detection-endpoint',
    ContentType='application/json',
    Body=json.dumps({"feature1": 0.5, "feature2": 1.2})
)
result = json.loads(response['Body'].read())
```

## Monitoring

### CloudWatch Dashboard

Access the dashboard URL from the Terraform outputs:
```bash
terraform output dashboard_url
```

### Alarms

The following alarms are configured:
- **High Latency**: Triggers when model latency > 1000ms
- **High Error Rate**: Triggers when 4XX errors > 10 in 5 minutes
- **Endpoint Failure**: Triggers when no invocations for 30 minutes

### Logs

- Lambda logs: `/aws/lambda/fraud-detection-prediction-lambda-<env>`
- SageMaker logs: `/aws/sagemaker/Endpoints/<endpoint-name>`

## Auto-Scaling

The SageMaker endpoint auto-scales based on:
- Metric: `SageMakerVariantInvocationsPerInstance`
- Target: 70 invocations per instance
- Scale-out cooldown: 60 seconds
- Scale-in cooldown: 300 seconds

## Cost Optimization

1. **Instance Type**: Start with `ml.t2.medium` for development
2. **Auto-scaling**: Adjust min/max instances based on load
3. **DynamoDB**: Uses on-demand pricing
4. **S3 Lifecycle**: Ol