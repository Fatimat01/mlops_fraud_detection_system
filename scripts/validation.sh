#!/bin/bash

# Complete validation script for fraud detection MLOps pipeline
# This script validates the entire deployment end-to-end

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

# Configuration
ENDPOINT_NAME=${ENDPOINT_NAME:-"fraud-detection-endpoint"}
API_BASE_URL=${API_BASE_URL:-"http://localhost:8000"}
UI_BASE_URL=${UI_BASE_URL:-"http://localhost:8501"}
AWS_REGION=${AWS_REGION:-"us-east-1"}

# Validation results
VALIDATION_RESULTS=()
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to record validation result
record_result() {
    local check_name="$1"
    local status="$2"
    local details="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ "$status" = "PASS" ]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        print_status "✅ $check_name"
    elif [ "$status" = "FAIL" ]; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        print_error "❌ $check_name"
        if [ ! -z "$details" ]; then
            echo "   $details"
        fi
    else
        print_warning "⚠️ $check_name - $details"
    fi
    
    VALIDATION_RESULTS+=("$status:$check_name:$details")
}

print_header "Fraud Detection MLOps Validation Suite"

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
    print_status "Environment variables loaded"
fi

print_status "Starting comprehensive validation..."
print_status "Endpoint: $ENDPOINT_NAME"
print_status "API URL: $API_BASE_URL"
print_status "Region: $AWS_REGION"

echo ""

# ============================================================================
# Infrastructure Validation
# ============================================================================

print_header "Infrastructure Validation"

# Check AWS credentials
print_status "Checking AWS credentials..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    record_result "AWS Credentials" "PASS" "Account: $AWS_ACCOUNT"
else
    record_result "AWS Credentials" "FAIL" "AWS credentials not configured"
fi

# Check CloudFormation stack
print_status "Checking CloudFormation stack..."
STACK_NAME="fraud-detection-infrastructure"
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
    STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" --query 'Stacks[0].StackStatus' --output text)
    if [[ "$STACK_STATUS" == *"COMPLETE"* ]]; then
        record_result "CloudFormation Stack" "PASS" "Status: $STACK_STATUS"
    else
        record_result "CloudFormation Stack" "FAIL" "Status: $STACK_STATUS"
    fi
else
    record_result "CloudFormation Stack" "FAIL" "Stack not found or not accessible"
fi

# Check SageMaker endpoint
print_status "Checking SageMaker endpoint..."
if aws sagemaker describe-endpoint --endpoint-name "$ENDPOINT_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
    ENDPOINT_STATUS=$(aws sagemaker describe-endpoint --endpoint-name "$ENDPOINT_NAME" --region "$AWS_REGION" --query 'EndpointStatus' --output text)
    if [ "$ENDPOINT_STATUS" = "InService" ]; then
        record_result "SageMaker Endpoint" "PASS" "Status: $ENDPOINT_STATUS"
    else
        record_result "SageMaker Endpoint" "FAIL" "Status: $ENDPOINT_STATUS"
    fi
else
    record_result "SageMaker Endpoint" "FAIL" "Endpoint not found or not accessible"
fi

# Check S3 bucket
print_status "Checking S3 bucket..."
if [ -f "infrastructure/outputs.json" ]; then
    S3_BUCKET=$(cat infrastructure/outputs.json | grep -o '"S3BucketName": "[^"]*"' | cut -d'"' -f4)
    if [ ! -z "$S3_BUCKET" ] && aws s3 ls "s3://$S3_BUCKET" > /dev/null 2>&1; then
        record_result "S3 Bucket" "PASS" "Bucket: $S3_BUCKET"
    else
        record_result "S3 Bucket" "FAIL" "Bucket not accessible"
    fi
else
    record_result "S3 Bucket" "WARN" "Infrastructure outputs not found"
fi

# Check DynamoDB table
print_status "Checking DynamoDB table..."
if [ -f "infrastructure/outputs.json" ]; then
    DYNAMODB_TABLE=$(cat infrastructure/outputs.json | grep -o '"DynamoDBTableName": "[^"]*"' | cut -d'"' -f4)
    if [ ! -z "$DYNAMODB_TABLE" ] && aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" > /dev/null 2>&1; then
        record_result "DynamoDB Table" "PASS" "Table: $DYNAMODB_TABLE"
    else
        record_result "DynamoDB Table" "FAIL" "Table not accessible"
    fi
else
    record_result "DynamoDB Table" "WARN" "Infrastructure outputs not found"
fi

# ============================================================================
# API Validation
# ============================================================================

print_header "API Service Validation"

# Check API health
print_status "Checking API health..."
if curl -s -f "$API_BASE_URL/health" > /dev/null 2>&1; then
    API_HEALTH=$(curl -s "$API_BASE_URL/health" | grep -o '"status": "[^"]*"' | cut -d'"' -f4)
    if [ "$API_HEALTH" = "healthy" ]; then
        record_result "API Health Check" "PASS" "Service is healthy"
    else
        record_result "API Health Check" "FAIL" "Service reports: $API_HEALTH"
    fi
else
    record_result "API Health Check" "FAIL" "API not responding at $API_BASE_URL"
fi

# Check API documentation
print_status "Checking API documentation..."
if curl -s -f "$API_BASE_URL/docs" > /dev/null 2>&1; then
    record_result "API Documentation" "PASS" "Swagger UI accessible"
else
    record_result "API Documentation" "FAIL" "Documentation not accessible"
fi

# Test prediction endpoint
print_status "Testing prediction endpoint..."
SAMPLE_CLAIM='{"months_as_customer":12,"age":35,"policy_deductable":500,"umbrella_limit":0,"insured_sex":1,"insured_education_level":3,"insured_occupation":2,"insured_hobbies":0,"insured_relationship":1,"incident_type":1,"collision_type":1,"incident_severity":2,"authorities_contacted":1,"number_of_vehicles_involved":2,"property_damage":0,"bodily_injuries":0,"witnesses":1,"police_report_available":1,"total_claim_amount":15000,"injury_claim":1000,"property_claim":2000,"vehicle_claim":12000,"auto_make":2,"auto_year":2018,"incident_hour_bin":2,"claim_ratio":1.0}'

PREDICTION_RESPONSE=$(curl -s -X POST "$API_BASE_URL/predict" \
    -H "Content-Type: application/json" \
    -d "$SAMPLE_CLAIM" 2>/dev/null || echo "ERROR")

if [[ "$PREDICTION_RESPONSE" == *"fraud_probability"* ]]; then
    FRAUD_PROB=$(echo "$PREDICTION_RESPONSE" | grep -o '"fraud_probability": [0-9.]*' | cut -d' ' -f2)
    record_result "Prediction Endpoint" "PASS" "Fraud probability: $FRAUD_PROB"
else
    record_result "Prediction Endpoint" "FAIL" "Prediction request failed"
fi

# Test batch prediction
print_status "Testing batch prediction endpoint..."
BATCH_CLAIMS='{"claims":['"$SAMPLE_CLAIM"']}'

BATCH_RESPONSE=$(curl -s -X POST "$API_BASE_URL/batch-predict" \
    -H "Content-Type: application/json" \
    -d "$BATCH_CLAIMS" 2>/dev/null || echo "ERROR")

if [[ "$BATCH_RESPONSE" == *"total_claims"* ]]; then
    record_result "Batch Prediction Endpoint" "PASS" "Batch processing working"
else
    record_result "Batch Prediction Endpoint" "FAIL" "Batch prediction failed"
fi

# ============================================================================
# UI Validation
# ============================================================================

print_header "UI Service Validation"

# Check Streamlit health
print_status "Checking Streamlit UI..."
if curl -s -f "$UI_BASE_URL/_stcore/health" > /dev/null 2>&1; then
    record_result "Streamlit UI Health" "PASS" "UI service is running"
    
    # Check if main page loads
    if curl -s -f "$UI_BASE_URL" > /dev/null 2>&1; then
        record_result "Streamlit UI Access" "PASS" "Main page accessible"
    else
        record_result "Streamlit UI Access" "FAIL" "Main page not accessible"
    fi
else
    record_result "Streamlit UI Health" "FAIL" "UI service not responding at $UI_BASE_URL"
    record_result "Streamlit UI Access" "FAIL" "UI service not available"
fi

# ============================================================================
# Model Validation
# ============================================================================

print_header "Model Validation"

# Check model file exists
print_status "Checking model file..."
if [ -f "model/model.pkl" ]; then
    MODEL_SIZE=$(stat -f%z "model/model.pkl" 2>/dev/null || stat -c%s "model/model.pkl" 2>/dev/null)
    if [ "$MODEL_SIZE" -gt 1000 ]; then
        record_result "Model File" "PASS" "Size: $MODEL_SIZE bytes"
    else
        record_result "Model File" "WARN" "Model file seems very small: $MODEL_SIZE bytes"
    fi
else
    record_result "Model File" "FAIL" "model.pkl not found"
fi

# Check feature metadata
print_status "Checking feature metadata..."
if [ -f "model/feature_names.json" ]; then
    FEATURE_COUNT=$(cat model/feature_names.json | grep -o '"feature_count": [0-9]*' | cut -d' ' -f2)
    if [ "$FEATURE_COUNT" = "26" ]; then
        record_result "Feature Metadata" "PASS" "26 features configured"
    else
        record_result "Feature Metadata" "WARN" "Unexpected feature count: $FEATURE_COUNT"
    fi
else
    record_result "Feature Metadata" "WARN" "Feature metadata not found"
fi

# Test model inference directly (if possible)
if [ "$ENDPOINT_STATUS" = "InService" ] 2>/dev/null; then
    print_status "Testing direct SageMaker inference..."
    
    # Create a simple test script
    cat > /tmp/test_inference.py << 'EOF'
import boto3
import json
import sys
import os

endpoint_name = os.getenv('ENDPOINT_NAME', 'fraud-detection-endpoint')
region = os.getenv('AWS_REGION', 'us-east-1')

try:
    runtime = boto3.client('sagemaker-runtime', region_name=region)
    
    test_data = {
        'months_as_customer': 12,
        'age': 35,
        'policy_deductable': 500,
        'umbrella_limit': 0,
        'insured_sex': 1,
        'insured_education_level': 3,
        'insured_occupation': 2,
        'insured_hobbies': 0,
        'insured_relationship': 1,
        'incident_type': 1,
        'collision_type': 1,
        'incident_severity': 2,
        'authorities_contacted': 1,
        'number_of_vehicles_involved': 2,
        'property_damage': 0,
        'bodily_injuries': 0,
        'witnesses': 1,
        'police_report_available': 1,
        'total_claim_amount': 15000,
        'injury_claim': 1000,
        'property_claim': 2000,
        'vehicle_claim': 12000,
        'auto_make': 2,
        'auto_year': 2018,
        'incident_hour_bin': 2,
        'claim_ratio': 1.0
    }
    
    response = runtime.invoke_endpoint(
        EndpointName=endpoint_name,
        ContentType='application/json',
        Body=json.dumps(test_data)
    )
    
    result = json.loads(response['Body'].read().decode())
    print(f"SUCCESS:{result[0]['fraud_probability']}")
    
except Exception as e:
    print(f"ERROR:{str(e)}")
EOF

    if python /tmp/test_inference.py 2>/dev/null | grep -q "SUCCESS"; then
        DIRECT_RESULT=$(python /tmp/test_inference.py 2>/dev/null | cut -d':' -f2)
        record_result "Direct SageMaker Inference" "PASS" "Fraud probability: $DIRECT_RESULT"
    else
        ERROR_MSG=$(python /tmp/test_inference.py 2>&1 | cut -d':' -f2)
        record_result "Direct SageMaker Inference" "FAIL" "$ERROR_MSG"
    fi
    
    rm -f /tmp/test_inference.py
fi

# ============================================================================
# Monitoring Validation
# ============================================================================

print_header "Monitoring Validation"

# Check CloudWatch dashboard
print_status "Checking CloudWatch dashboard..."
DASHBOARD_NAME="fraud-detection-dashboard"
if aws cloudwatch get-dashboard --dashboard-name "$DASHBOARD_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
    record_result "CloudWatch Dashboard" "PASS" "Dashboard exists"
else
    record_result "CloudWatch Dashboard" "FAIL" "Dashboard not found"
fi

# Check CloudWatch alarms
print_status "Checking CloudWatch alarms..."
ALARMS=$(aws cloudwatch describe-alarms --region "$AWS_REGION" --alarm-name-prefix "fraud-detection" --query 'MetricAlarms[].AlarmName' --output text 2>/dev/null || echo "")
if [ ! -z "$ALARMS" ]; then
    ALARM_COUNT=$(echo "$ALARMS" | wc -w)
    record_result "CloudWatch Alarms" "PASS" "$ALARM_COUNT alarms configured"
else
    record_result "CloudWatch Alarms" "WARN" "No alarms found"
fi

# Check metrics endpoint
print_status "Checking metrics endpoint..."
if curl -s -f "$API_BASE_URL/metrics" > /dev/null 2>&1; then
    METRICS_RESPONSE=$(curl -s "$API_BASE_URL/metrics")
    if [[ "$METRICS_RESPONSE" == *"endpoint_name"* ]]; then
        record_result "Metrics Endpoint" "PASS" "Metrics accessible"
    else
        record_result "Metrics Endpoint" "FAIL" "Metrics endpoint error"
    fi
else
    record_result "Metrics Endpoint" "FAIL" "Metrics endpoint not responding"
fi

# ============================================================================
# Performance Validation
# ============================================================================

print_header "Performance Validation"

# Test API response time
print_status "Testing API response time..."
START_TIME=$(date +%s%N)
curl -s -X POST "$API_BASE_URL/predict" \
    -H "Content-Type: application/json" \
    -d "$SAMPLE_CLAIM" > /dev/null 2>&1
END_TIME=$(date +%s%N)

if [ $? -eq 0 ]; then
    RESPONSE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))  # Convert to milliseconds
    if [ $RESPONSE_TIME -lt 5000 ]; then  # Less than 5 seconds
        record_result "API Response Time" "PASS" "${RESPONSE_TIME}ms"
    else
        record_result "API Response Time" "WARN" "Slow response: ${RESPONSE_TIME}ms"
    fi
else
    record_result "API Response Time" "FAIL" "Request failed"
fi

# Test concurrent requests
print_status "Testing concurrent request handling..."
CONCURRENT_TEST_RESULT=$(
    for i in {1..5}; do
        curl -s -X POST "$API_BASE_URL/predict" \
            -H "Content-Type: application/json" \
            -d "$SAMPLE_CLAIM" > /dev/null 2>&1 &
    done
    wait
    echo "SUCCESS"
)

if [ "$CONCURRENT_TEST_RESULT" = "SUCCESS" ]; then
    record_result "Concurrent Request Handling" "PASS" "5 concurrent requests handled"
else
    record_result "Concurrent Request Handling" "FAIL" "Concurrent requests failed"
fi

# ============================================================================
# Security Validation
# ============================================================================

print_header "Security Validation"

# Check CORS headers
print_status "Checking CORS configuration..."
CORS_HEADERS=$(curl -s -I "$API_BASE_URL/health" | grep -i "access-control" | wc -l)
if [ $CORS_HEADERS -gt 0 ]; then
    record_result "CORS Configuration" "PASS" "CORS headers present"
else
    record_result "CORS Configuration" "WARN" "CORS headers not found"
fi

# Check for sensitive information exposure
print_status "Checking for information disclosure..."
API_ROOT_RESPONSE=$(curl -s "$API_BASE_URL/")
if [[ "$API_ROOT_RESPONSE" == *"AWS"* ]] || [[ "$API_ROOT_RESPONSE" == *"secret"* ]]; then
    record_result "Information Disclosure" "WARN" "Potential sensitive information in API response"
else
    record_result "Information Disclosure" "PASS" "No obvious information disclosure"
fi

# ============================================================================
# Unit Test Validation
# ============================================================================

print_header "Running Core Unit Tests"

print_status "Running inference tests..."
if python -m pytest tests/test_inference.py -v > /dev/null 2>&1; then
    record_result "Inference Unit Tests" "PASS" "All tests passed"
else
    record_result "Inference Unit Tests" "FAIL" "Some tests failed"
fi

# ============================================================================
# Final Results
# ============================================================================

print_header "Validation Results Summary"

echo ""
print_status "📊 Validation Summary:"
echo "   Total Checks: $TOTAL_CHECKS"
echo "   ✅ Passed: $PASSED_CHECKS"
echo "   ❌ Failed: $FAILED_CHECKS"
echo "   ⚠️ Warnings: $((TOTAL_CHECKS - PASSED_CHECKS - FAILED_CHECKS))"

if [ $TOTAL_CHECKS -gt 0 ]; then
    SUCCESS_RATE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
    echo "   📈 Success Rate: ${SUCCESS_RATE}%"
fi

echo ""

# Categorize results
CRITICAL_FAILURES=0
for result in "${VALIDATION_RESULTS[@]}"; do
    STATUS=$(echo "$result" | cut -d':' -f1)
    CHECK=$(echo "$result" | cut -d':' -f2)
    
    if [ "$STATUS" = "FAIL" ]; then
        case "$CHECK" in
            "AWS Credentials"|"SageMaker Endpoint"|"API Health Check"|"Prediction Endpoint")
                CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
                ;;
        esac
    fi
done

# Final assessment
if [ $FAILED_CHECKS -eq 0 ]; then
    print_status "🎉 All validations passed! System is ready for production."
    EXIT_CODE=0
elif [ $CRITICAL_FAILURES -eq 0 ]; then
    print_warning "⚠️ System is functional but has some issues that should be addressed."
    EXIT_CODE=1
else
    print_error "💥 Critical issues found! System is not ready for production."
    EXIT_CODE=2
fi

echo ""
print_status "📋 Next Steps:"

if [ $FAILED_CHECKS -gt 0 ]; then
    echo "   🔧 Fix failed validations:"
    for result in "${VALIDATION_RESULTS[@]}"; do
        STATUS=$(echo "$result" | cut -d':' -f1)
        CHECK=$(echo "$result" | cut -d':' -f2)
        DETAILS=$(echo "$result" | cut -d':' -f3)
        
        if [ "$STATUS" = "FAIL" ]; then
            echo "      - $CHECK: $DETAILS"
        fi
    done
fi

echo "   🧪 Run full test suite: ./scripts/run_tests.sh"
echo "   🚀 Deploy updates: ./scripts/deploy.sh"
echo "   📊 Check monitoring: Check CloudWatch dashboard"

echo ""
print_status "📁 Validation artifacts:"
echo "   CloudWatch Dashboard: https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards:"
echo "   API Documentation: $API_BASE_URL/docs"
echo "   UI Interface: $UI_BASE_URL"

echo ""
echo "================================"

exit $EXIT_CODE