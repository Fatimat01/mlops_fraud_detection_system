# Fraud Detection Model - Deployment Implementation Guide

## Overview

This guide walks through deploying an XGBoost fraud detection model to AWS SageMaker with complete MLOps practices including:
- Infrastructure as Code (CloudFormation)
- Auto-scaling SageMaker endpoints
- CloudWatch monitoring and alerting
- FastAPI for model serving
- Docker containerization
- DynamoDB for prediction logging
- API Gateway for external access

## Architecture

```
[CloudFormation Stack]
         ├── S3 Bucket (Model Storage)
         ├── IAM Roles (SageMaker Execution)
         ├── SNS Topic (Email Alerts)
         ├── CloudWatch Alarms
         ├── Lambda Functions (Monitoring)
         ├── API Gateway
         └── DynamoDB Table
                ↓
    [SageMaker Endpoint] ← [Auto-scaling]
                ↓
         [FastAPI App] ← [Docker Container]
```

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Python 3.8+** installed
3. **Docker** installed
4. **AWS CLI** configured (`aws configure`)
5. **Trained XGBoost model** saved as `model.pkl`

## Step-by-Step Deployment

### Step 1: Environment Setup

```bash
# Clone repository
cd fraud-detection-deployment

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Setup environment variables
cp .env.example .env
# Edit .env with your configuration:
# - AWS_REGION=us-east-1
# - ENDPOINT_NAME=fraud-detection-endpoint
# - ALERT_EMAIL=your-email@example.com
```

### Step 2: Place Your Model

```bash
# Create model directory and place your model
mkdir -p model
cp /path/to/your/model.pkl model/model.pkl
```

### Step 3: Deploy Infrastructure with CloudFormation

```bash
# Deploy the complete infrastructure
python infrastructure/deploy_infrastructure.py \
    --model-name fraud-detection-model \
    --endpoint-name fraud-detection-endpoint \
    --alert-email your-email@example.com \
    --instance-type ml.m5.xlarge \
    --min-instances 1 \
    --max-instances 4 \
    --environment prod
```

This creates:
- **S3 Bucket**: For model artifacts with encryption
- **IAM Roles**: SageMaker execution role with necessary permissions
- **CloudWatch Alarms**: High latency, error rate, and CPU utilization
- **SNS Topic**: Email notifications for alerts
- **DynamoDB Table**: Store predictions with TTL
- **API Gateway**: RESTful API endpoint
- **Lambda Functions**: Hourly monitoring and alert processing

### Step 4: Deploy Model to SageMaker

```bash
# Deploy model to SageMaker endpoint
python src/deploy.py --endpoint-name fraud-detection-endpoint
```

This will:
1. Package model with inference code
2. Upload to S3 bucket created by CloudFormation
3. Create SageMaker model
4. Deploy endpoint with initial configuration
5. Setup auto-scaling (1-4 instances)
6. Test endpoint with sample data

### Step 5: Run Tests

```bash
# Unit tests
pytest tests/test_inference.py -v

# Integration tests (requires deployed endpoint)
pytest tests/test_endpoint.py -v

# Test endpoint directly
python api/client.py --endpoint fraud-detection-endpoint --performance-test
```

### Step 6: Build and Run Docker Container

```bash
# Build Docker image
docker build -f docker/Dockerfile -t fraud-detection-api:latest .

# Run container
docker run -d \
    --name fraud-api \
    -p 8000:8000 \
    -e ENDPOINT_NAME=fraud-detection-endpoint \
    -e AWS_REGION=us-east-1 \
    -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    fraud-detection-api:latest

# Or use docker-compose
docker-compose up -d
```

### Step 7: Access the API

1. **FastAPI Documentation**: http://localhost:8000/docs
2. **Health Check**: http://localhost:8000/health
3. **Make Prediction**:
```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d @api/sample_claim.json
```

### Step 8: Monitor Your Deployment

1. **CloudWatch Dashboard**:
   - Go to AWS Console → CloudWatch → Dashboards
   - Open `fraud-detection-endpoint-dashboard`

2. **Check Metrics**:
```bash
python src/monitor.py fraud-detection-endpoint
```

3. **Cost Analysis**:
```bash
python scripts/check_costs.py --endpoint fraud-detection-endpoint
```

## Automated Deployment

For a complete automated deployment, run:

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

This script will:
1. Deploy CloudFormation infrastructure
2. Validate model file exists
3. Run unit tests
4. Deploy model to SageMaker
5. Setup monitoring
6. Run integration tests
7. Build and start Docker container
8. Display deployment summary

## API Usage Examples

### Single Prediction
```python
import requests

url = "http://localhost:8000/predict"
claim_data = {
    "claim_id": "CLM-001",
    "months_as_customer": 5,
    "age": 35,
    "policy_deductable": 500,
    "umbrella_limit": 0,
    "insured_sex": 1,
    "insured_education_level": 2,
    "insured_occupation": 3,
    "insured_hobbies": 0,
    "insured_relationship": 0,
    "incident_type": 1,
    "collision_type": 1,
    "incident_severity": 2,
    "authorities_contacted": 0,
    "number_of_vehicles_involved": 1,
    "property_damage": 0,
    "bodily_injuries": 0,
    "witnesses": 1,
    "police_report_available": 1,
    "total_claim_amount": 10000,
    "injury_claim": 1000,
    "property_claim": 2000,
    "vehicle_claim": 3000,
    "auto_make": 1,
    "auto_year": 2018,
    "incident_hour_bin": 3,
    "claim_ratio": 0.33
}

response = requests.post(url, json=claim_data)
print(response.json())
```

### Batch Prediction
```python
url = "http://localhost:8000/batch-predict"
claims = [claim_data1, claim_data2, claim_data3]
response = requests.post(url, json=claims)
print(response.json())
```

## Monitoring Stack

The deployment uses **CloudWatch** as the primary monitoring solution because:

1. **Native Integration**: Built-in support for SageMaker metrics
2. **Comprehensive Metrics**: Latency, invocations, errors, CPU/memory
3. **Automated Alerts**: SNS integration for email notifications
4. **Cost Effective**: No additional infrastructure required
5. **Dashboards**: Pre-configured visualizations

### Key Metrics Monitored:
- **Model Latency**: Average and P99 response times
- **Invocations**: Request volume and patterns
- **Error Rates**: 4XX and 5XX errors
- **Resource Utilization**: CPU and memory usage
- **Auto-scaling**: Instance count changes

### Alerts Configured:
- High latency (>1 second average)
- High error rate (>5 errors in 5 minutes)
- High CPU utilization (>80%)
- Daily cost monitoring via Lambda

## Auto-scaling Configuration

The endpoint scales automatically based on:
- **Metric**: Invocations per instance
- **Target**: 100 invocations/instance
- **Scale-out**: Add instance when above target (60s cooldown)
- **Scale-in**: Remove instance when below target (300s cooldown)
- **Limits**: 1-4 instances

## Clean Up Resources

To avoid ongoing charges:

```bash
# Delete all resources
python scripts/cleanup.py \
    --endpoint-name fraud-detection-endpoint \
    --stack-name fraud-detection-infrastructure

# Or manually:
# 1. Delete endpoint
aws sagemaker delete-endpoint --endpoint-name fraud-detection-endpoint

# 2. Delete CloudFormation stack (this removes all other resources)
aws cloudformation delete-stack --stack-name fraud-detection-infrastructure
```

## Troubleshooting

### Endpoint Not Responding
```bash
# Check status
aws sagemaker describe-endpoint --endpoint-name fraud-detection-endpoint

# View logs
aws logs tail /aws/sagemaker/endpoints/fraud-detection-endpoint
```

### Docker Container Issues
```bash
# Check container logs
docker logs fraud-api

# Restart container
docker restart fraud-api
```

### CloudFormation Issues
```bash
# Check stack events
aws cloudformation describe-stack-events \
    --stack-name fraud-detection-infrastructure \
    --max-items 10
```

## Cost Optimization

- **Instance Type**: ml.m5.xlarge provides good balance
- **Auto-scaling**: Reduces costs during low traffic
- **Spot Instances**: Consider for development/testing
- **Monitoring**: Lambda functions run hourly (minimal cost)

Estimated monthly costs:
- SageMaker Endpoint: ~$200 (with auto-scaling)
- S3 Storage: ~$5
- CloudWatch/Lambda: ~$10
- DynamoDB: ~$5 (pay-per-request)

## Security Best Practices

1. **IAM Roles**: Least privilege access configured
2. **S3 Encryption**: AES-256 enabled
3. **API Gateway**: IAM authentication required
4. **VPC**: Can be configured for network isolation
5. **Secrets**: Use AWS Secrets Manager for API keys

## Next Steps

1. **CI/CD Pipeline**: Integrate with GitHub Actions/Jenkins
2. **Model Versioning**: Implement model registry
3. **A/B Testing**: Use SageMaker multi-model endpoints
4. **Advanced Monitoring**: Add custom metrics
5. **API Authentication**: Add API key management