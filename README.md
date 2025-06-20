# 🚀 Insurance Fraud Detection - Production MLOps Deployment

A production-ready MLOps pipeline for deploying XGBoost fraud detection models on AWS SageMaker using FastAPI, Docker, Terraform, and GitHub Actions.

> **Note**: Model training is performed in a separate repository: [Insurance Fraud Prediction](https://github.com/Fatimat01/insurance-fraud-prediction)

## 🎯 Overview

This project implements a complete MLOps deployment pipeline for fraud detection in insurance claims. It takes a trained XGBoost model and deploys it as a scalable, production-ready API on AWS SageMaker.

### Key Features

- ✅ **Automated Deployment**: GitHub Actions CI/CD pipeline
- ✅ **Custom SageMaker Container**: FastAPI-based inference server
- ✅ **Infrastructure as Code**: Modular Terraform configuration
- ✅ **Cost Optimized**: Default ml.t2.medium instance
- ✅ **Monitoring**: CloudWatch dashboards and alarms
- ✅ **State Management**: S3 backend with DynamoDB locking

### Current Implementation Status

| Component | Status | Description |
|-----------|--------|-------------|
| SageMaker Endpoint | ✅ Implemented | Model serving with custom container |
| Docker Container | ✅ Implemented | FastAPI with SageMaker compatibility |
| S3 Storage | ✅ Implemented | Model artifacts with versioning |
| IAM Roles | ✅ Implemented | Secure access management |
| CloudWatch | ✅ Implemented | Basic monitoring and alerts |
| SSM Parameters | ✅ Implemented | Configuration management |
| DynamoDB | ⏳ Future | Prediction logging |
| API Gateway | ⏳ Future | Public API endpoint |
| Auto-scaling | ⏳ Future | Dynamic capacity management |
| Lambda Functions | ⏳ Future | Serverless processing |



## 📚 Prerequisites

### Required Tools

- **Python 3.10+** - [Download](https://www.python.org/downloads/)
- **Docker Desktop** - [Download](https://www.docker.com/products/docker-desktop)
- **Terraform >= 1.0** - [Download](https://www.terraform.io/downloads)
- **AWS CLI v2** - [Download](https://aws.amazon.com/cli/)
- **Git** - [Download](https://git-scm.com/downloads)

### AWS Requirements

- AWS Account with appropriate IAM permissions
- Pre-configured S3 bucket for Terraform state: 
- Pre-configured DynamoDB table for state locking: 

### Required IAM Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sagemaker:*",
        "ecr:*",
        "s3:*",
        "iam:*",
        "cloudwatch:*",
        "sns:*",
        "ssm:*",
        "dynamodb:*"
      ],
      "Resource": "*"
    }
  ]
}
```
Use least-privilege scoped IAM user for CI/CD automation.

## 🛠️ Environment Setup

### 1. Clone the Repository

```bash
git clone https://github.com/Fatimat01/mlops_fraud_detection_system.git
cd fraud-detection-mlops
```

### 2. Set Up Python Environment

```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Linux/Mac:
source venv/bin/activate
# On Windows:
# venv\Scripts\activate

# Upgrade pip
pip install --upgrade pip

# Install dependencies
pip install -r requirements.txt
```

### 3. Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Enter your credentials:
# AWS Access Key ID: [your-access-key]
# AWS Secret Access Key: [your-secret-key]
# Default region name: us-east-1
# Default output format: json

# Verify credentials
aws sts get-caller-identity
```


### 4. Prepare Model Artifact

Ensure your trained model is in the correct location:

```bash
# The model should be at:
model/model.pkl

# Package the model
cd model/
tar -czf model.tar.gz model.pkl
cd ..
```


## 📁 Project Structure

```
fraud-detection-mlops/
├── .github/
│   └── workflows/
│       ├── image.yml          # Docker build & push to ECR
│       ├── infra.yml          # Terraform deployment
│       └── cleanup.yml        # Resource cleanup
├── app/
│   ├── main.py               # FastAPI application
│   └── serve.py              # SageMaker entry point
├── infra/
│   └── terraform/
│       ├── backend.tf        # S3 state backend
│       ├── main.tf           # Main configuration
│       ├── variables.tf      # Input variables
│       ├── outputs.tf        # Output values
│       ├── versions.tf       # Provider versions
│       └── modules/
│           ├── s3/           # Model storage
│           ├── iam/          # IAM roles & policies
│           ├── sagemaker/    # Endpoint configuration
│           ├── dynamodb/     # Prediction logging (future)
│           ├── monitoring/   # CloudWatch & SNS
│           ├── ssm_parameters/ # Parameter store
│           ├── api_gateway/  # API Gateway (future)
│           └── lambda/       # Lambda functions (future)
├── model/
│   └── model.pkl             # Trained XGBoost model
├── predictions/
│   └── result.json           # Sample prediction output
├── src/
│   ├── code/
│   │   └── inference.py      # Model inference logic (not used)
│   ├── feature_names.json    # Feature schema
│   └── metrics_collector.py  # Custom metrics (not used)
├── test/
│   └── test-endpoint.py      # Endpoint testing script
├── Dockerfile                # Container definition
├── requirements.txt          # Python dependencies
├── .gitignore               # Git ignore rules
└── README.md                # This file
```

## ⚙️ Configuration

### Terraform Variables (`terraform.tfvars`)

```hcl
aws_region = "us-east-1"

# Project Configuration
project_name = "fraud-detection"
environment  = "prod"

# SageMaker Configuration
endpoint_name = "fraud-detection-endpoint"
model_name    = "fraud-detection-model"
instance_type = "ml.t2.medium"
min_instances = 1
max_instances = 2

# Model Artifact S3 URI (leave empty to create new bucket)
# model_artifact_s3_uri = ""

# Alert Configuration
alert_email = "set your email for notification"
# Note: Auto-scaling not yet implemented
```

## 🚢 Deployment

### Automated Deployment (GitHub Actions)

Push to the `main` branch triggers automatic deployment:

```bash
# For Docker image updates
git add app/ model/ Dockerfile
git commit -m "Update model and API"
git push origin main

# For infrastructure updates
git add infra/terraform/
git commit -m "Update infrastructure"
git push origin main
```

### Manual Deployment

#### 1. Build and Push Docker Image

```bash
# Build image
docker build -t fraud-detection:latest .

# Get ECR login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com

# Tag and push
docker tag fraud-detection:latest \
  $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com/fraud-detection:latest

docker push \
  $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com/fraud-detection:latest
```

#### 2. Deploy Infrastructure

```bash
cd infra/terraform

# Initialize (first time only)
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Get outputs
terraform output
```

## 📡 API Reference

### SageMaker Endpoint

The model is deployed as a SageMaker endpoint that accepts JSON requests with fraud detection features.

#### Endpoint Invocation

```python
import boto3
import json

# Initialize SageMaker runtime client
runtime = boto3.client('sagemaker-runtime', region_name='us-east-1')

# Prepare payload
payload = {
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

# Invoke endpoint
response = runtime.invoke_endpoint(
    EndpointName='fraud-detection-endpoint',
    ContentType='application/json',
    Body=json.dumps(payload)
)

# Parse response
result = json.loads(response['Body'].read().decode())
print(f"Fraud Probability: {result['fraud_probability'][0]:.2%}")
print(f"Risk Level: {result['detailed_predictions'][0]['risk_level']}")
```

#### Response Format

```json
{
  "predictions": [0.0168],
  "fraud_probability": [0.0168],
  "detailed_predictions": [
    {
      "fraud_probability": 0.0168,
      "is_fraud": false,
      "risk_level": "LOW",
      "confidence": 0.9664
    }
  ],
  "metadata": {
    "model_version": "1.0",
    "prediction_count": 1,
    "timestamp": "2025-06-20T03:49:44.533225"
  }
}
```

### FastAPI Endpoints (Container Internal)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/ping` | GET | Health check endpoint |
| `/invocations` | POST | Prediction endpoint |
| `/` | GET | API information |
| `/model-info` | GET | Model metadata |

## 🧪 Testing

### Test Deployed Endpoint

```bash
# Using the test script
python test/test-endpoint.py

# Using AWS CLI
aws sagemaker-runtime invoke-endpoint \
  --endpoint-name fraud-detection-endpoint \
  --body file://test/sample_payload.json \
  --content-type application/json \
  response.json

cat response.json
```

### Local Testing

```bash
# Run FastAPI locally
cd app
uvicorn main:app --reload --port 8080

# Test local endpoint
curl http://localhost:8080/ping
curl -X POST http://localhost:8080/invocations \
  -H "Content-Type: application/json" \
  -d @../test/sample_payload.json
```

## 📊 Monitoring

### CloudWatch Dashboard

Access the monitoring dashboard:

```bash
cd infra/terraform
terraform output dashboard_url
```

### Available Metrics

- **Endpoint Invocations**: Total predictions made
- **Model Latency**: Response time metrics
- **Error Rates**: 4XX and 5XX errors
- **Resource Utilization**: CPU and memory usage

### Configured Alarms

| Alarm | Threshold | Description |
|-------|-----------|-------------|
| High Latency | > 1000ms | Model response time |
| High Error Rate | > 10 errors in 5 min | Client errors |
| Endpoint Failure | < 1 invocation in 30 min | Health check |


## 🔄 CI/CD Pipeline

### Workflow Triggers

| Workflow | Trigger | Actions |
|----------|---------|---------|
| `image.yml` | Push to `app/`, `model/`, `Dockerfile` | Build & push Docker image |
| `infra.yml` | Push to `infra/terraform/` | Deploy infrastructure |
| `cleanup.yml` | Manual dispatch | Destroy all resources |

### GitHub Secrets Required

```yaml
AWS_ACCESS_KEY_ID: Your AWS access key
AWS_SECRET_ACCESS_KEY: Your AWS secret key
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Model Not Found Error
```
Error: Model /opt/ml/model/model.pkl cannot be loaded
```
**Solution**: Ensure model.tar.gz is properly created and uploaded:
```bash
cd model
tar -czf model.tar.gz model.pkl
aws s3 cp model.tar.gz s3://your-bucket/model/
```

#### 2. Docker Platform Error
```
WARNING: The requested image's platform does not match
```
**Solution**: Build for linux/amd64:
```bash
docker build --platform linux/amd64 -t fraud-detection:latest .
```

#### 3. Terraform State Lock
```
Error: Error acquiring the state lock
```
**Solution**: Remove stale lock:
```bash
aws dynamodb delete-item \
  --table-name fatimat-tf-state-lock \
  --key '{"LockID":{"S":"fatimat-tf-state/fraud-detection.tfstate"}}'
```

## 🚧 Future Enhancements

### Planned Features

1. **Auto-scaling**
   - Dynamic capacity based on traffic
   - Scheduled scaling for business hours
   - Cost optimization through right-sizing

2. **API Gateway Integration**
   - Public REST API endpoint
   - API key management
   - Rate limiting and throttling

3. **DynamoDB Logging**
   - Prediction history storage
   - Analytics and reporting
   - Audit trail

4. **Lambda Functions**
   - Pre/post-processing
   - Batch predictions
   - Async processing

5. **Enhanced Monitoring**
   - Custom business metrics
   - Model drift detection
   - A/B testing support

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Model training: [Insurance Fraud Prediction](https://github.com/Fatimat01/insurance-fraud-prediction)
- XGBoost team for the excellent gradient boosting library
- FastAPI for the modern, fast web framework
- AWS SageMaker team for the managed ML platform

---

**Maintainer**: Fatimat Atanda  
**Contact**: atandafatimat01@gmail.com  
