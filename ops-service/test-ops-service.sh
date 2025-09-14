#!/bin/bash

# Viralogic Ops Service Test Script
# =================================
# This script tests the functionality of the Viralogic Ops Service

set -e

# Configuration
OPS_URL="https://ops.viralogic.io"
API_KEY="${AI_MONITORING_API_KEY:-viralogic-ai-uuqrOYQxuXlCGyYoz3uePzLEUwuaPaHLRlhG6IUgBmI}"
TIMEOUT=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test functions
test_endpoint() {
    local endpoint="$1"
    local description="$2"
    local auth_required="$3"
    local expected_status="$4"
    
    echo -e "${BLUE}Testing: ${description}${NC}"
    echo "Endpoint: ${endpoint}"
    
    local cmd="curl -s -w '%{http_code}' -o /dev/null --max-time ${TIMEOUT}"
    
    if [ "$auth_required" = "true" ]; then
        cmd="${cmd} -H 'x-api-key: ${API_KEY}'"
    fi
    
    cmd="${cmd} '${OPS_URL}${endpoint}'"
    
    local status_code
    status_code=$(eval "$cmd")
    
    if [ "$status_code" = "$expected_status" ]; then
        echo -e "${GREEN}✓ PASS${NC} (Status: ${status_code})"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} (Expected: ${expected_status}, Got: ${status_code})"
        return 1
    fi
}

test_json_response() {
    local endpoint="$1"
    local description="$2"
    local auth_required="$3"
    
    echo -e "${BLUE}Testing JSON Response: ${description}${NC}"
    echo "Endpoint: ${endpoint}"
    
    local cmd="curl -s --max-time ${TIMEOUT}"
    
    if [ "$auth_required" = "true" ]; then
        cmd="${cmd} -H 'x-api-key: ${API_KEY}'"
    fi
    
    cmd="${cmd} '${OPS_URL}${endpoint}'"
    
    local response
    response=$(eval "$cmd")
    
    if echo "$response" | jq . >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC} (Valid JSON)"
        echo "Response preview: $(echo "$response" | jq -r 'keys[]' 2>/dev/null | head -3 | tr '\n' ', ')"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} (Invalid JSON)"
        echo "Response: ${response:0:200}..."
        return 1
    fi
}

# Main test execution
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Viralogic Ops Service Test Suite${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required for JSON testing. Please install jq.${NC}"
    exit 1
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is required for testing. Please install curl.${NC}"
    exit 1
fi

echo -e "${BLUE}Configuration:${NC}"
echo "  Ops URL: ${OPS_URL}"
echo "  API Key: ${API_KEY:0:20}..."
echo "  Timeout: ${TIMEOUT}s"
echo ""

# Test counters
total_tests=0
passed_tests=0

# Run tests
echo -e "${YELLOW}Running Tests...${NC}"
echo ""

# Public endpoints (no auth required)
echo -e "${BLUE}=== Public Endpoints ===${NC}"
test_endpoint "/" "Service Information" "false" "200" && ((passed_tests++))
((total_tests++))

test_endpoint "/health" "Health Check" "false" "200" && ((passed_tests++))
((total_tests++))

test_json_response "/" "Service Information JSON" "false" && ((passed_tests++))
((total_tests++))

test_json_response "/health" "Health Check JSON" "false" && ((passed_tests++))
((total_tests++))

echo ""

# AI Agent endpoints (auth required)
echo -e "${BLUE}=== AI Agent Endpoints ===${NC}"
test_endpoint "/api/overview" "System Overview" "true" "200" && ((passed_tests++))
((total_tests++))

test_endpoint "/api/services" "Services Status" "true" "200" && ((passed_tests++))
((total_tests++))

test_endpoint "/api/services/backend" "Backend Service Details" "true" "200" && ((passed_tests++))
((total_tests++))

test_endpoint "/api/logs?limit=1" "Logs Endpoint" "true" "200" && ((passed_tests++))
((total_tests++))

test_endpoint "/api/monitoring/backend" "Backend Monitoring" "true" "200" && ((passed_tests++))
((total_tests++))

test_endpoint "/api/metrics" "System Metrics" "true" "200" && ((passed_tests++))
((total_tests++))

test_json_response "/api/overview" "System Overview JSON" "true" && ((passed_tests++))
((total_tests++))

test_json_response "/api/services" "Services Status JSON" "true" && ((passed_tests++))
((total_tests++))

echo ""

# Authentication tests
echo -e "${BLUE}=== Authentication Tests ===${NC}"
test_endpoint "/api/overview" "Unauthorized Access (no key)" "false" "401" && ((passed_tests++))
((total_tests++))

test_endpoint "/api/overview" "Invalid API Key" "true" "401" && ((passed_tests++))
((total_tests++))

echo ""

# Error handling tests
echo -e "${BLUE}=== Error Handling Tests ===${NC}"
test_endpoint "/api/services/nonexistent" "Non-existent Service" "true" "404" && ((passed_tests++))
((total_tests++))

test_endpoint "/api/nonexistent" "Non-existent Endpoint" "true" "404" && ((passed_tests++))
((total_tests++))

echo ""

# Test summary
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Test Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo "Total Tests: ${total_tests}"
echo -e "Passed: ${GREEN}${passed_tests}${NC}"
echo -e "Failed: ${RED}$((total_tests - passed_tests))${NC}"

if [ $passed_tests -eq $total_tests ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed!${NC}"
    exit 1
fi
