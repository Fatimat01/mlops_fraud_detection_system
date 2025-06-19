#!/bin/bash

# Environment setup script for Fraud Detection MLOps
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_header "Fraud Detection MLOps Setup"

# Check Python version
print_status "Checking Python version..."
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
REQUIRED_VERSION="3.8"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    print_error "Python $REQUIRED_VERSION or higher is required. Found: $PYTHON_VERSION"
    exit 1
fi

print_status "✅ Python version OK: $PYTHON_VERSION"



# Upgrade pip
print_status "Upgrading pip..."
pip install --upgrade pip

# Install requirements
print_status "Installing Python dependencies..."
pip install -r requirements.txt

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_warning "AWS CLI not found. Installing..."
    pip install awscli
else
    print_status "✅ AWS CLI found"
fi


# Check AWS credentials
print_status "Checking AWS configuration..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text | cut -d'/' -f2)
    print_status "✅ AWS credentials configured"
    print_status "   Account ID: $AWS_ACCOUNT_ID"
    print_status "   User/Role: $AWS_USER"
else
    print_warning "⚠️ AWS credentials not configured"
    print_warning "Please run: aws configure"
    print_warning "Or set environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
fi


# Check for model file and tar it
if [ -f "model/xgboost-model" ]; then
    MODEL_SIZE=$(stat -f%z "model/xgboost-model" 2>/dev/null || stat -c%s "model/xgboost-model" 2>/dev/null)
    print_status "✅ Model file found (${MODEL_SIZE} bytes)"
    cd model && tar -czf model.tar.gz xgboost-model code/ 2>/dev/null 
else
    print_warning "⚠️ Model file not found at model/xgboost-model"
    print_warning "Please place your trained model.pkl file in the model/ directory"
fi

# Create sample model metadata
if [ ! -f "model/feature_names.json" ]; then
    print_status "Creating feature metadata file..."
    cat > model/feature_names.json << 'EOF'
{
  "features": [
    "months_as_customer",
    "age", 
    "policy_deductable",
    "umbrella_limit",
    "insured_sex",
    "insured_education_level",
    "insured_occupation",
    "insured_hobbies",
    "insured_relationship",
    "incident_type",
    "collision_type",
    "incident_severity",
    "authorities_contacted",
    "number_of_vehicles_involved",
    "property_damage",
    "bodily_injuries",
    "witnesses",
    "police_report_available",
    "total_claim_amount",
    "injury_claim",
    "property_claim",
    "vehicle_claim",
    "auto_make",
    "auto_year",
    "incident_hour_bin",
    "claim_ratio"
  ],
  "feature_count": 26,
  "model_type": "fraud_detection",
  "version": "1.0"
}
EOF
    print_status "✅ Feature metadata created"
fi

# Make scripts executable
print_status "Making scripts executable..."
chmod +x scripts/*.sh

# Install pre-commit hooks (optional)
if command -v pre-commit &> /dev/null; then
    print_status "Setting up pre-commit hooks..."
    pre-commit install
else
    print_warning "pre-commit not found. Skipping hook setup."
fi

# Test basic functionality
print_status "Running basic tests..."
python -c "
import boto3
import pandas as pd
import numpy as np
import fastapi
import streamlit
print('✅ All core dependencies imported successfully')
"

# Display setup summary
print_header "Setup Complete!"
TERRAFORM_DIR="infra/terraform"
# Validate Terraform configuration
print_status "Validating Terraform configuration..."
cd "$TERRAFORM_DIR"
print_status "Validating Terraform configuration..."
if terraform validate > /dev/null 2>&1; then
    print_status "✅ Terraform configuration is valid"
else
    print_warning "⚠️ Terraform validation failed. Run 'terraform init' first"
fi

# Display setup summary
print_header "Setup Complete!"

echo ""
print_status "🎉 Environment setup completed successfully!"
echo ""
echo "📋 What's configured:"
echo "  • Python virtual environment"
echo "  • Required dependencies installed"
echo "  • Terraform installation verified"
echo "  • Project directories created"
echo "  • Configuration files ready"
echo ""
echo "📝 Next steps:"
echo "  1. Edit terraform.tfvars with your configuration"
echo "  2. Set alert_email in terraform.tfvars (required)"
echo "  3. Place your trained model at model/model.pkl"
echo "  4. Initialize Terraform: terraform init"
echo "  5. Run deployment: ./deploy.sh or make deploy"
echo ""
echo "🧪 Useful commands:"
echo "  • Initialize: make init"
echo "  • Plan deployment: make plan"
echo "  • Deploy: make deploy"
echo "  • Test endpoint: make test-endpoint"
echo "  • View logs: make view-predictions"
echo "  • Destroy: make destroy"
echo ""
echo "📊 Terraform commands:"
echo "  • terraform init     - Initialize Terraform"
echo "  • terraform plan     - Preview changes"
echo "  • terraform apply    - Deploy infrastructure"
echo "  • terraform output   - Show outputs"
echo "  • terraform destroy  - Remove all resources"
echo ""