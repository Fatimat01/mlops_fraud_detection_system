#!/bin/bash
# Complete deployment automation script for Terraform

set -e

echo "======================================"
echo "Fraud Detection Model Deployment (Terraform)"
echo "======================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
TERRAFORM_DIR="../infra/terraform"
# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Function to check Terraform installation
check_terraform() {
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Error: Terraform not installed${NC}"
        echo "Please run ./setup.sh first"
        exit 1
    fi
}

# Function to check if infrastructure is deployed
check_infrastructure() {
    cd "$TERRAFORM_DIR"
    if terraform output -json 2>/dev/null | jq -e '.sagemaker_endpoint_name.value' > /dev/null; then
        echo -e "${GREEN}✓ Infrastructure outputs found${NC}"
        return 0
    else
        return 1
    fi
}

# Function to get Terraform output value
get_terraform_output() {
    cd "$TERRAFORM_DIR"
    terraform output -raw "$1" 2>/dev/null || echo ""
}

# Check prerequisites
check_terraform

# Step 1: Initialize Terraform
echo -e "\n${YELLOW}Step 1: Initializing Terraform${NC}"
cd "$TERRAFORM_DIR"
if [ ! -d ".terraform" ]; then
    terraform init
    if [ $? -ne 0 ]; then
        echo -e "${RED}Terraform initialization failed!${NC}"
        exit 1
    fi
else
    echo "Terraform already initialized"
fi

# Step 2: Validate Configuration
echo -e "\n${YELLOW}Step 2: Validating Configuration${NC}"
terraform validate
if [ $? -ne 0 ]; then
    echo -e "${RED}Terraform validation failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Configuration valid${NC}"

# Check for required variables
if [ -f "terraform.tfvars" ]; then
    ALERT_EMAIL=$(grep "alert_email" terraform.tfvars | cut -d'"' -f2 | grep "@" || echo "")
    if [ -z "$ALERT_EMAIL" ] || [ "$ALERT_EMAIL" = "your-email@example.com" ]; then
        echo -e "${RED}Error: Please set a valid alert_email in terraform.tfvars${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: terraform.tfvars not found${NC}"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and configure it"
    exit 1
fi

# Step 3: Deploy Infrastructure
echo -e "\n${YELLOW}Step 3: Deploying Infrastructure${NC}"
if ! check_infrastructure; then
    echo "Infrastructure not deployed. Running Terraform apply..."
    
    # Show plan first
    terraform plan -out=tfplan --no-color
    
    echo -e "\n${YELLOW}Review the plan above. Do you want to proceed? (yes/no)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Deployment cancelled"
        rm -f tfplan
        exit 0
    fi
    
    # Apply the plan
    terraform apply tfplan -auto-approve --no-color
    rm -f tfplan
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Infrastructure deployment failed!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Infrastructure deployed successfully${NC}"
else
    echo "Infrastructure already deployed. Use 'terraform apply' to update."
fi

cd "../"

# Get infrastructure outputs
ENDPOINT_NAME=$(get_terraform_output "sagemaker_endpoint_name")
S3_BUCKET=$(get_terraform_output "s3_bucket_name")
DYNAMODB_TABLE=$(get_terraform_output "dynamodb_table_name")
API_GATEWAY_URL=$(get_terraform_output "api_gateway_url")
LAMBDA_FUNCTION=$(get_terraform_output "lambda_function_name")
REGION=$(get_terraform_output "region")

# Step 4: Check Model File
echo -e "\n${YELLOW}Step 4: Checking Model File${NC}"
if [ ! -f "model/model.pkl" ]; then
    echo -e "${RED}Error: model.pkl not found in model/ directory${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Model file found${NC}"

# Step 5: Upload Model to S3
echo -e "\n${YELLOW}Step 5: Uploading Model to S3${NC}"
if [ -n "$S3_BUCKET" ]; then
    # Create model tarball
    cd model
    tar -czf ../model.tar.gz model.pkl *.py 2>/dev/null || tar -czf ../model.tar.gz model.pkl
    cd ..
    
    # Upload to S3
    aws s3 cp model.tar.gz "s3://${S3_BUCKET}/model/model.tar.gz"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Model uploaded to S3${NC}"
    else
        echo -e "${RED}Model upload failed!${NC}"
        exit 1
    fi
    
    # Clean up
    rm -f model.tar.gz
else
    echo -e "${RED}S3 bucket not found in outputs${NC}"
    exit 1
fi

# Step 6: Update SageMaker Model (if needed)
echo -e "\n${YELLOW}Step 6: Updating SageMaker Model${NC}"
# Force update of the SageMaker model to use the new artifact
cd "$TERRAFORM_DIR"
terraform apply -target=module.sagemaker -auto-approve
cd "$../scripts"

# Step 7: Run Unit Tests
echo -e "\n${YELLOW}Step 7: Running Unit Tests${NC}"
if [ -f "tests/test_inference.py" ]; then
    pytest tests/test_inference.py -v
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Warning: Unit tests failed${NC}"
    else
        echo -e "${GREEN}✓ Unit tests passed${NC}"
    fi
else
    echo -e "${YELLOW}Unit test file not found, skipping${NC}"
fi

# Step 8: Test Lambda Function
echo -e "\n${YELLOW}Step 8: Testing Lambda Function${NC}"
if [ -n "$LAMBDA_FUNCTION" ]; then
    # Create test payload
    TEST_PAYLOAD='{
        "body": {
            "months_as_customer": 12,
            "age": 35,
            "policy_deductable": 500,
            "umbrella_limit": 1000000,
            "insured_sex": "MALE",
            "insured_education_level": "MD",
            "insured_occupation": "exec-managerial",
            "insured_hobbies": "sleeping",
            "insured_relationship": "husband",
            "incident_type": "Single Vehicle Collision",
            "collision_type": "Side Collision",
            "incident_severity": "Minor Damage",
            "authorities_contacted": "Police",
            "number_of_vehicles_involved": 1,
            "property_damage": "NO",
            "bodily_injuries": 0,
            "witnesses": 1,
            "police_report_available": "YES",
            "total_claim_amount": 5000,
            "injury_claim": 0,
            "property_claim": 0,
            "vehicle_claim": 5000,
            "auto_make": "Toyota",
            "auto_year": 2015,
            "incident_hour_bin": "afternoon",
            "claim_ratio": 0.5
        }
    }'
    
    echo "$TEST_PAYLOAD" > ./test_payload.json
    
    # Invoke Lambda
    aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION" \
        --payload file:///./test_payload.json \
        --cli-binary-format raw-in-base64-out \
        ./lambda_response.json
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Lambda function test successful${NC}"
        echo "Response:"
        cat /tmp/lambda_response.json | jq '.'
    else
        echo -e "${YELLOW}Lambda test failed${NC}"
    fi
    
    # Clean up
    rm -f ./test_payload.json ./lambda_response.json
fi

# Step 9: Test API Gateway Endpoint
echo -e "\n${YELLOW}Step 9: Testing API Gateway${NC}"
if [ -n "$API_GATEWAY_URL" ]; then
    echo "Testing endpoint: $API_GATEWAY_URL"
    
    curl -X POST "$API_GATEWAY_URL" \
        -H "Content-Type: application/json" \
        -d '{
            "months_as_customer": 12,
            "age": 35,
            "total_claim_amount": 5000,
            "policy_deductable": 500,
            "umbrella_limit": 1000000,
            "insured_sex": "MALE",
            "insured_education_level": "MD",
            "insured_occupation": "exec-managerial",
            "insured_hobbies": "sleeping",
            "insured_relationship": "husband",
            "incident_type": "Single Vehicle Collision",
            "collision_type": "Side Collision",
            "incident_severity": "Minor Damage",
            "authorities_contacted": "Police",
            "number_of_vehicles_involved": 1,
            "property_damage": "NO",
            "bodily_injuries": 0,
            "witnesses": 1,
            "police_report_available": "YES",
            "injury_claim": 0,
            "property_claim": 0,
            "vehicle_claim": 5000,
            "auto_make": "Toyota",
            "auto_year": 2015,
            "incident_hour_bin": "afternoon",
            "claim_ratio": 0.5
        }' \
        -w "\n"
    
    echo -e "\n${GREEN}✓ API Gateway test completed${NC}"
fi

# Step 10: Build and Start API Docker Container (Optional)
echo -e "\n${YELLOW}Step 10: Building Docker Container (Optional)${NC}"
if [ -f "docker/Dockerfile" ] && command -v docker &> /dev/null; then
    docker build -f docker/Dockerfile -t fraud-detection-api:latest .
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Docker image built successfully${NC}"
        
        # Stop any existing container
        docker stop fraud-api 2>/dev/null || true
        docker rm fraud-api 2>/dev/null || true
        
        # Start new container
        echo "Starting Docker container..."
        docker run -d \
            --name fraud-api \
            -p 8000:8000 \
            -e ENDPOINT_NAME="$ENDPOINT_NAME" \
            -e AWS_REGION="$REGION" \
            fraud-detection-api:latest
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ API container started${NC}"
        fi
    fi
else
    echo -e "${YELLOW}Docker not found or Dockerfile missing, skipping${NC}"
fi

# Get CloudWatch Dashboard URL
DASHBOARD_URL=$(get_terraform_output "dashboard_url")

# Display deployment summary
echo -e "\n${GREEN}======================================"
echo "DEPLOYMENT COMPLETE!"
echo "======================================"
echo -e "${NC}"
echo "Infrastructure Details:"
echo "  • Endpoint: $ENDPOINT_NAME"
echo "  • Region: $REGION"
echo "  • S3 Bucket: $S3_BUCKET"
echo "  • DynamoDB Table: $DYNAMODB_TABLE"
echo "  • Lambda Function: $LAMBDA_FUNCTION"
echo ""
echo "API Access:"
echo "  • API Gateway: $API_GATEWAY_URL"
echo ""
echo "Monitoring:"
echo "  • CloudWatch Dashboard: $DASHBOARD_URL"
echo ""

if docker ps | grep -q fraud-api; then
    echo "Local API Access (via Docker):"
    echo "  • Docs: http://localhost:8000/docs"
    echo "  • Health: http://localhost:8000/health"
    echo "  • Predict: http://localhost:8000/predict"
    echo ""
fi

echo "Test Commands:"
echo "  • Test endpoint: make test-endpoint"
echo "  • View predictions: make view-predictions"
echo "  • Check alarms: make monitor-alarms"
echo ""
echo "Management Commands:"
echo "  • View outputs: terraform output"
echo "  • Update infrastructure: terraform apply"
echo "  • Destroy resources: terraform destroy"
echo ""
echo "Cost Optimization:"
echo "  • Current auto-scaling: $(get_terraform_output 'auto_scaling_configuration')"
echo "  • To modify, update terraform.tfvars and run: terraform apply"
echo "======================================"