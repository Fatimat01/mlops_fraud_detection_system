# Fraud Detection MLOps - Quick Reference

## 🚀 Quick Start

```bash
# 1. Setup environment
./scripts/setup.sh

# 2. Configure (REQUIRED: set alert_email)
vi infra/terraform/terraform.tfvars

# 3. Deploy everything
./scripts/deploy.sh

# 4. Test the deployment
python api/client.py
```

## 📁 Key Files & Locations

```
Project Structure:
├── model/
│   ├── model.pkl          # Your trained model
│   └── inference.py       # SageMaker inference script
├── infra/terraform/
│   ├── terraform.tfvars   # Your configuration
│   └── main.tf           # Infrastructure code
├── scripts/
│   ├── setup.sh          # Environment setup
│   ├── deploy.sh         # Deployment automation
│   └── cleanup.sh        # Resource cleanup
└── api/
    ├── main.py           # FastAPI application
    └── client.py         # Test client
```

## 🛠️ Common Commands

### Terraform Operations
```bash
cd infra/terraform

# Deploy
terraform init
terraform plan
terraform apply

# Update specific module
terraform apply -target=module.sagemaker

# Get outputs
terraform output
terraform output api_gateway_url

# Destroy
terraform destroy
```

### Testing
```bash
# Test API Gateway
curl -X POST $(cd infra/terraform && terraform output -raw api_gateway_url) \
  -H "Content-Type: application/json" \
  -d @api/sample_claim.json

# Test with Python client
python api/client.py --health
python api/client.py --claim-file api/sample_claim.json
python api/client.py --batch

# Test SageMaker directly
aws sagemaker-runtime invoke-endpoint \
  --endpoint-name fraud-detection-endpoint \
  --body '{"age": 35, "total_claim_amount": 5000}' \
  --content-type application/json \
  response.json
```

### Docker Operations
```bash
# Build and run FastAPI
docker build -f docker/Dockerfile -t fraud-detection-api .
docker run -d -p 8000:8000 --name fraud-api \
  -e ENDPOINT_NAME=fraud-detection-endpoint \
  fraud-detection-api

# Using docker-compose
docker-compose -f docker/docker-compose.yml up -d

# View logs
docker logs fraud-api -f

# Stop and remove
docker stop fraud-api && docker rm fraud-api
```

### Monitoring
```bash
# View recent predictions
aws dynamodb scan \
  --table-name fraud-detection-predictions \
  --limit 5 \
  --query 'Items[*].{ID:prediction_id.S,Time:timestamp.S}' \
  --output table

# Check endpoint status
aws sagemaker describe-endpoint \
  --endpoint-name fraud-detection-endpoint \
  --query 'EndpointStatus'

# View Lambda logs
aws logs tail /aws/lambda/fraud-detection-prediction-lambda-prod --follow

# Check alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix "fraud-detection"
```

## 🔧 Configuration Reference

### terraform.tfvars
```hcl
# Minimal configuration
alert_email = "your@email.com"  # REQUIRED

# Full configuration
aws_region = "us-east-1"
project_name = "fraud-detection"
environment = "prod"
endpoint_name = "fraud-detection-endpoint"
model_name = "fraud-detection-model"
instance_type = "ml.m5.large"
min_instances = 1
max_instances = 4
ml_framework = "sklearn"  # or "xgboost"
```

### Environment Variables (.env)
```bash
AWS_REGION=us-east-1
ENDPOINT_NAME=fraud-detection-endpoint
DYNAMODB_TABLE=fraud-detection-predictions
API_PORT=8000
```

## 🚨 Troubleshooting

### Common Issues
```bash
# Terraform init fails
rm -rf infra/terraform/.terraform
cd infra/terraform && terraform init -upgrade

# Model not found
ls -la model/  # Check model.pkl exists

# Endpoint unhealthy
aws sagemaker describe-endpoint \
  --endpoint-name fraud-detection-endpoint

# API Gateway 500 error
aws logs tail /aws/lambda/fraud-detection-prediction-lambda-prod

# Docker permission denied
sudo usermod -aG docker $USER && newgrp docker
```

### Debug Commands
```bash
# List all resources
cd infra/terraform && terraform state list

# Check AWS resources
aws sagemaker list-endpoints
aws s3 ls | grep fraud
aws dynamodb list-tables | grep fraud

# Force state refresh
cd infra/terraform && terraform refresh
```

## 💰 Cost Control

```bash
# Stop endpoint (save ~$85/month)
aws sagemaker update-endpoint-weights-and-capacities \
  --endpoint-name fraud-detection-endpoint \
  --desired-weight-and-capacity VariantName=AllTraffic,DesiredInstanceCount=0

# Restart endpoint
aws sagemaker update-endpoint-weights-and-capacities \
  --endpoint-name fraud-detection-endpoint \
  --desired-weight-and-capacity VariantName=AllTraffic,DesiredInstanceCount=1

# Check costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '7 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost \
  --filter '{"Tags": {"Key": "Project", "Values": ["fraud-detection"]}}'
```

## 🧹 Cleanup

```bash
# Full cleanup
./scripts/cleanup.sh

# Keep Terraform state
./scripts/cleanup.sh --keep-state

# Quick destroy
cd infra/terraform && terraform destroy -auto-approve
```

## 📊 Useful Makefile Commands

```bash
cd infra/terraform

make help              # Show all commands
make init             # Initialize Terraform
make plan             # Preview changes
make deploy           # Full deployment
make test-endpoint    # Test the endpoint
make view-predictions # View recent predictions
make monitor-alarms   # Check alarm status
make destroy          # Tear down everything
```

## 🔗 Quick Links

After deployment, access:
- **API Docs**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health
- **CloudWatch**: `terraform output dashboard_url`
- **API Gateway**: `terraform output api_gateway_url`

## 📝 Notes

- Always set `alert_email` before deploying
- Start with `ml.t2.medium` for testing
- Model file must be named `model.pkl`
- Include `inference.py` with your model
- Check CloudWatch Logs for errors
- Use tags for cost tracking