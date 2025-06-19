#!/bin/bash
# Complete deployment automation script for Terraform

set -e

# Get the project root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
TERRAFORM_DIR="$PROJECT_ROOT/infra/terraform"

# Change to project root
cd "$PROJECT_ROOT"

echo "======================================"
echo "Fraud Detection Model Deployment (Terraform)"
echo "======================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi


# Check Model File and tar it with inference script
if [ -f "model/model.pkl" ]; then
    MODEL_SIZE=$(stat -f%z "model/model.pkl" 2>/dev/null || stat -c%s "model/model.pkl" 2>/dev/null)
    print_status "✅ Model file found (${MODEL_SIZE} bytes)"
    tar -czf model/model.tar.gz model/model.pkl model/code/ 2>/dev/null || tar -czf model/model.tar.gz model/model.pkl
else
    print_warning "⚠️ Model file not found at model/model.pkl"
    print_warning "Please place your trained model.pkl file in the model/ directory"
fi

# Function to check Terraform installation
check_terraform() {
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Error: Terraform not installed${NC}"
        exit 1
    fi
}

# Function to check if infrastructure is deployed
check_infrastructure() {
    cd "$TERRAFORM_DIR"
    if terraform output -json 2>/dev/null | jq -e '.sagemaker_endpoint_name.value' > /dev/null; then
        echo -e "${GREEN}✓ Infrastructure outputs found${NC}"
        cd "$PROJECT_ROOT"
        return 0
    else
        cd "$PROJECT_ROOT"
        return 1
    fi
}

# Function to get Terraform output value
get_terraform_output() {
    cd "$TERRAFORM_DIR"
    local value=$(terraform output -raw "$1" 2>/dev/null || echo "")
    cd "$PROJECT_ROOT"
    echo "$value"
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
        echo -e "${RED}Error: Please set a valid alert_email in infra/terraform/terraform.tfvars${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: terraform.tfvars not found in infra/terraform/${NC}"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and configure it"
    exit 1
fi

# Step 3: Deploy Infrastructure
echo -e "\n${YELLOW}Step 3: Deploying Infrastructure${NC}"
if ! check_infrastructure; then
    echo "Infrastructure not deployed. Running Terraform apply..."
    
    # Show plan first
    terraform plan -out=tfplan
    
    echo -e "\n${YELLOW}Review the plan above. Do you want to proceed? (yes/no)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Deployment cancelled"
        rm -f tfplan
        exit 0
    fi
    
    # Apply the plan
    terraform apply tfplan
    rm -f tfplan
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Infrastructure deployment failed!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Infrastructure deployed successfully${NC}"
else
    echo "Infrastructure already deployed. Use 'cd infra/terraform && terraform apply' to update."
fi

# Return to project root
cd "$PROJECT_ROOT"

# Get infrastructure outputs
ENDPOINT_NAME=$(get_terraform_output "sagemaker_endpoint_name")
S3_BUCKET=$(get_terraform_output "s3_bucket_name")
DYNAMODB_TABLE=$(get_terraform_output "dynamodb_table_name")
API_GATEWAY_URL=$(get_terraform_output "api_gateway_url")
LAMBDA_FUNCTION=$(get_terraform_output "lambda_function_name")
REGION=$(get_terraform_output "region")



# # Step 5: Upload Model to S3
# echo -e "\n${YELLOW}Step 5: Uploading Model to S3${NC}"
# if [ -n "$S3_BUCKET" ]; then
#     # Check if inference.py exists in model directory
#     if [ ! -f "model/inference.py" ]; then
#         echo -e "${YELLOW}Creating inference.py for SageMaker${NC}"
#         # Copy inference script to model directory
#         if [ -f "src/inference.py" ]; then
#             cp "src/inference.py" "model/"
#         else
#             echo -e "${RED}Warning: inference.py not found. The model may not work properly.${NC}"
#             echo -e "${YELLOW}Please create model/inference.py or src/inference.py${NC}"
#         fi
#     fi
    
#     # Create model tarball with all necessary files
#     cd model
#     echo "Creating model archive with:"
#     ls -la model.pkl inference.py 2>/dev/null || ls -la model.pkl
    
#     # Create tar.gz with model and inference script
#     if [ -f "inference.py" ]; then
#         tar -czf ../model.tar.gz model.pkl inference.py
#     else
#         echo -e "${YELLOW}Warning: Creating archive without inference.py${NC}"
#         tar -czf ../model.tar.gz model.pkl
#     fi
#     cd ..
    
#     # Upload to S3
#     aws s3 cp model.tar.gz "s3://${S3_BUCKET}/model/model.tar.gz"
    
#     if [ $? -eq 0 ]; then
#         echo -e "${GREEN}✓ Model uploaded to S3${NC}"
#     else
#         echo -e "${RED}Model upload failed!${NC}"
#         exit 1
#     fi
    
#     # Clean up
#     rm -f model.tar.gz
# else
#     echo -e "${RED}S3 bucket not found in outputs${NC}"
#     exit 1
# fi

# Step 6: Update SageMaker Model (if needed)
echo -e "\n${YELLOW}Step 6: Updating SageMaker Model${NC}"
# Force update of the SageMaker model to use the new artifact
cd "$TERRAFORM_DIR"
terraform apply -target=module.sagemaker -auto-approve
cd "$PROJECT_ROOT"

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
    
    echo "$TEST_PAYLOAD" > /tmp/test_payload.json
    
    # Invoke Lambda
    aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION" \
        --payload file:///tmp/test_payload.json \
        --cli-binary-format raw-in-base64-out \
        /tmp/lambda_response.json
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Lambda function test successful${NC}"
        echo "Response:"
        cat /tmp/lambda_response.json | jq '.'
    else
        echo -e "${YELLOW}Lambda test failed${NC}"
    fi
    
    # Clean up
    rm -f /tmp/test_payload.json /tmp/lambda_response.json
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
echo "  • Test endpoint: cd infra/terraform && make test-endpoint"
echo "  • View predictions: cd infra/terraform && make view-predictions"
echo "  • Check alarms: cd infra/terraform && make monitor-alarms"
echo ""
echo "Management Commands:"
echo "  • View outputs: cd infra/terraform && terraform output"
echo "  • Update infrastructure: cd infra/terraform && terraform apply"
echo "  • Destroy resources: cd infra/terraform && terraform destroy"
echo ""
echo "Cost Optimization:"
echo "  • Current auto-scaling: $(get_terraform_output 'auto_scaling_configuration')"
echo "  • To modify, update infra/terraform/terraform.tfvars and run: cd infra/terraform && terraform apply"
echo "======================================"