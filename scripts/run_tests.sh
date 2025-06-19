#!/bin/bash

# Comprehensive test runner for fraud detection MLOps pipeline
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
TEST_TIMEOUT=300
COVERAGE_THRESHOLD=80
PARALLEL_JOBS=4

# Parse command line arguments
RUN_UNIT=true
RUN_INTEGRATION=true
RUN_API=true
RUN_MONITORING=true
RUN_DATA_VALIDATION=true
RUN_COVERAGE=false
VERBOSE=false
FAST_MODE=false
GENERATE_REPORT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --unit-only)
            RUN_INTEGRATION=false
            RUN_API=false
            RUN_MONITORING=false
            shift
            ;;
        --integration-only)
            RUN_UNIT=false
            RUN_API=false
            RUN_MONITORING=false
            RUN_DATA_VALIDATION=false
            shift
            ;;
        --api-only)
            RUN_UNIT=false
            RUN_INTEGRATION=false
            RUN_MONITORING=false
            RUN_DATA_VALIDATION=false
            shift
            ;;
        --coverage)
            RUN_COVERAGE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --fast)
            FAST_MODE=true
            TEST_TIMEOUT=60
            shift
            ;;
        --report)
            GENERATE_REPORT=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --unit-only           Run only unit tests"
            echo "  --integration-only    Run only integration tests"
            echo "  --api-only           Run only API tests"
            echo "  --coverage           Generate coverage report"
            echo "  --verbose            Verbose output"
            echo "  --fast               Fast mode (reduced timeouts)"
            echo "  --report             Generate HTML test report"
            echo "  --help               Show this help message"
            echo ""
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_header "Fraud Detection MLOps Test Suite"

# Initialize test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
START_TIME=$(date +%s)

# Create test results directory
TEST_RESULTS_DIR="test_results"
mkdir -p "$TEST_RESULTS_DIR"

# Setup environment
print_status "Setting up test environment..."

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    source venv/bin/activate
    print_status "Virtual environment activated"
fi

# Install test dependencies
if $RUN_COVERAGE; then
    pip install coverage pytest-cov pytest-html pytest-xdist > /dev/null 2>&1
fi

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
    print_status "Environment variables loaded"
fi

# Function to run pytest with common options
run_pytest() {
    local test_file="$1"
    local test_name="$2"
    local output_file="$TEST_RESULTS_DIR/${test_name}_results.xml"
    
    local pytest_args="--tb=short --strict-markers"
    
    if $VERBOSE; then
        pytest_args="$pytest_args -v"
    fi
    
    if $GENERATE_REPORT; then
        pytest_args="$pytest_args --junitxml=$output_file"
    fi
    
    if $RUN_COVERAGE && [[ "$test_name" != "integration" ]]; then
        pytest_args="$pytest_args --cov=src --cov=api --cov-append"
    fi
    
    if $FAST_MODE; then
        pytest_args="$pytest_args -x"  # Stop on first failure
    fi
    
    # Run tests
    python -m pytest $test_file $pytest_args
}

# Function to parse test results
parse_results() {
    local result_output="$1"
    
    # Extract test counts (this is a simplified parser)
    local passed=$(echo "$result_output" | grep -o '[0-9]* passed' | cut -d' ' -f1 | head -1)
    local failed=$(echo "$result_output" | grep -o '[0-9]* failed' | cut -d' ' -f1 | head -1)
    local skipped=$(echo "$result_output" | grep -o '[0-9]* skipped' | cut -d' ' -f1 | head -1)
    
    PASSED_TESTS=$((PASSED_TESTS + ${passed:-0}))
    FAILED_TESTS=$((FAILED_TESTS + ${failed:-0}))
    SKIPPED_TESTS=$((SKIPPED_TESTS + ${skipped:-0}))
    TOTAL_TESTS=$((TOTAL_TESTS + ${passed:-0} + ${failed:-0} + ${skipped:-0}))
}

# Unit Tests
if $RUN_UNIT; then
    print_header "Running Unit Tests"
    
    if [ -f "tests/test_inference.py" ]; then
        print_status "Running inference tests..."
        if result_output=$(run_pytest "tests/test_inference.py" "unit_inference" 2>&1); then
            print_status "✅ Inference tests passed"
        else
            print_error "❌ Inference tests failed"
            if $VERBOSE; then
                echo "$result_output"
            fi
        fi
        parse_results "$result_output"
    else
        print_warning "Inference tests not found"
    fi
fi

# Data Validation Tests
if $RUN_DATA_VALIDATION; then
    print_header "Running Data Validation Tests"
    
    if [ -f "tests/test_data_validation.py" ]; then
        print_status "Running data validation tests..."
        if result_output=$(run_pytest "tests/test_data_validation.py" "data_validation" 2>&1); then
            print_status "✅ Data validation tests passed"
        else
            print_error "❌ Data validation tests failed"
            if $VERBOSE; then
                echo "$result_output"
            fi
        fi
        parse_results "$result_output"
    else
        print_warning "Data validation tests not found"
    fi
fi

# API Tests
if $RUN_API; then
    print_header "Running API Tests"
    
    if [ -f "tests/test_api.py" ]; then
        print_status "Running API tests..."
        if result_output=$(run_pytest "tests/test_api.py" "api" 2>&1); then
            print_status "✅ API tests passed"
        else
            print_error "❌ API tests failed"
            if $VERBOSE; then
                echo "$result_output"
            fi
        fi
        parse_results "$result_output"
    else
        print_warning "API tests not found"
    fi
fi

# Monitoring Tests
if $RUN_MONITORING; then
    print_header "Running Monitoring Tests"
    
    if [ -f "tests/test_monitoring.py" ]; then
        print_status "Running monitoring tests..."
        if result_output=$(run_pytest "tests/test_monitoring.py" "monitoring" 2>&1); then
            print_status "✅ Monitoring tests passed"
        else
            print_error "❌ Monitoring tests failed"
            if $VERBOSE; then
                echo "$result_output"
            fi
        fi
        parse_results "$result_output"
    else
        print_warning "Monitoring tests not found"
    fi
fi

# Integration Tests
if $RUN_INTEGRATION; then
    print_header "Running Integration Tests"
    
    # Check if required services are running
    if ! curl -s http://localhost:8000/health > /dev/null 2>&1; then
        print_warning "API service not running at localhost:8000"
        print_warning "Integration tests may fail or be skipped"
    fi
    
    if [ -f "tests/test_integration.py" ]; then
        print_status "Running integration tests..."
        print_status "This may take several minutes..."
        
        if result_output=$(timeout $TEST_TIMEOUT run_pytest "tests/test_integration.py" "integration" 2>&1); then
            print_status "✅ Integration tests passed"
        else
            if [ $? -eq 124 ]; then
                print_error "❌ Integration tests timed out after ${TEST_TIMEOUT}s"
            else
                print_error "❌ Integration tests failed"
            fi
            if $VERBOSE; then
                echo "$result_output"
            fi
        fi
        parse_results "$result_output"
    else
        print_warning "Integration tests not found"
    fi
fi

# Coverage Report
if $RUN_COVERAGE; then
    print_header "Generating Coverage Report"
    
    print_status "Creating coverage report..."
    coverage html -d "$TEST_RESULTS_DIR/coverage_html" --skip-covered
    coverage report --show-missing > "$TEST_RESULTS_DIR/coverage_report.txt"
    
    # Check coverage threshold
    coverage_percentage=$(coverage report | grep TOTAL | awk '{print $4}' | sed 's/%//')
    
    if [ ! -z "$coverage_percentage" ]; then
        if (( $(echo "$coverage_percentage >= $COVERAGE_THRESHOLD" | bc -l) )); then
            print_status "✅ Coverage: ${coverage_percentage}% (meets threshold of ${COVERAGE_THRESHOLD}%)"
        else
            print_warning "⚠️ Coverage: ${coverage_percentage}% (below threshold of ${COVERAGE_THRESHOLD}%)"
        fi
    else
        print_warning "Could not determine coverage percentage"
    fi
    
    print_status "Coverage report saved to $TEST_RESULTS_DIR/coverage_html/index.html"
fi

# Generate HTML Test Report
if $GENERATE_REPORT; then
    print_header "Generating Test Report"
    
    # Combine all XML reports if they exist
    if ls "$TEST_RESULTS_DIR"/*_results.xml 1> /dev/null 2>&1; then
        print_status "Test reports saved to $TEST_RESULTS_DIR/"
        
        # Create a simple HTML summary
        cat > "$TEST_RESULTS_DIR/test_summary.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Fraud Detection Test Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; }
        .passed { color: green; }
        .failed { color: red; }
        .skipped { color: orange; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Fraud Detection MLOps Test Results</h1>
        <p>Generated on: $(date)</p>
    </div>
    
    <h2>Summary</h2>
    <table>
        <tr><th>Metric</th><th>Count</th></tr>
        <tr><td>Total Tests</td><td>$TOTAL_TESTS</td></tr>
        <tr><td class="passed">Passed</td><td>$PASSED_TESTS</td></tr>
        <tr><td class="failed">Failed</td><td>$FAILED_TESTS</td></tr>
        <tr><td class="skipped">Skipped</td><td>$SKIPPED_TESTS</td></tr>
    </table>
    
    <h2>Test Files</h2>
    <ul>
EOF

        for xml_file in "$TEST_RESULTS_DIR"/*_results.xml; do
            if [ -f "$xml_file" ]; then
                filename=$(basename "$xml_file")
                echo "        <li><a href=\"$filename\">$filename</a></li>" >> "$TEST_RESULTS_DIR/test_summary.html"
            fi
        done

        cat >> "$TEST_RESULTS_DIR/test_summary.html" << EOF
    </ul>
</body>
</html>
EOF

        print_status "HTML test summary saved to $TEST_RESULTS_DIR/test_summary.html"
    fi
fi

# Calculate execution time
END_TIME=$(date +%s)
EXECUTION_TIME=$((END_TIME - START_TIME))

# Final Results
print_header "Test Results Summary"

echo ""
print_status "📊 Test Execution Summary:"
echo "   Total Tests: $TOTAL_TESTS"
echo "   ✅ Passed: $PASSED_TESTS"
echo "   ❌ Failed: $FAILED_TESTS"
echo "   ⏭️ Skipped: $SKIPPED_TESTS"
echo "   ⏱️ Execution Time: ${EXECUTION_TIME}s"

if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    echo "   📈 Success Rate: ${SUCCESS_RATE}%"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        print_status "🎉 All tests passed!"
        exit_code=0
    else
        print_error "💥 Some tests failed!"
        exit_code=1
    fi
else
    print_warning "⚠️ No tests were executed!"
    exit_code=1
fi

echo ""
print_status "📁 Test artifacts:"
if [ -d "$TEST_RESULTS_DIR" ]; then
    echo "   Test results: $TEST_RESULTS_DIR/"
    
    if $RUN_COVERAGE; then
        echo "   Coverage report: $TEST_RESULTS_DIR/coverage_html/index.html"
    fi
    
    if $GENERATE_REPORT; then
        echo "   Test summary: $TEST_RESULTS_DIR/test_summary.html"
    fi
fi

echo ""
print_status "🔧 Useful commands:"
echo "   Run specific test type: $0 --unit-only"
echo "   Run with coverage: $0 --coverage"
echo "   Run with verbose output: $0 --verbose"
echo "   Generate reports: $0 --report --coverage"

if [ $FAILED_TESTS -gt 0 ]; then
    echo ""
    print_error "🔍 To debug failures:"
    echo "   Run with verbose: $0 --verbose"
    echo "   Run specific tests: python -m pytest tests/test_specific.py -v"
    echo "   Check logs in: logs/"
fi

echo ""
echo "================================"

exit $exit_code