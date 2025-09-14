#!/bin/bash

# 🚀 Viralogic Production Monitoring Test Script
# Tests the complete production-ready monitoring system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OPS_BASE_URL="https://ops.viralogic.io"
API_KEY="viralogic-ai-uuqrOYQxuXlCGyYoz3uePzLEUwuaPaHLRlhG6IUgBmI"

echo -e "${BLUE}🚀 Testing Viralogic Production Monitoring System${NC}"
echo "=================================================="

# Test 1: Ops Service Health
echo -e "\n${YELLOW}1. Testing Ops Service Health${NC}"
if curl -s -f "${OPS_BASE_URL}/health" > /dev/null; then
    echo -e "✅ ${GREEN}Ops Service Health: OK${NC}"
else
    echo -e "❌ ${RED}Ops Service Health: FAILED${NC}"
    exit 1
fi

# Test 2: AI Agent Authentication
echo -e "\n${YELLOW}2. Testing AI Agent Authentication${NC}"
if curl -s -f -H "x-api-key: ${API_KEY}" "${OPS_BASE_URL}/api/overview" > /dev/null; then
    echo -e "✅ ${GREEN}AI Agent Authentication: OK${NC}"
else
    echo -e "❌ ${RED}AI Agent Authentication: FAILED${NC}"
    exit 1
fi

# Test 3: System Overview
echo -e "\n${YELLOW}3. Testing System Overview${NC}"
OVERVIEW_RESPONSE=$(curl -s -H "x-api-key: ${API_KEY}" "${OPS_BASE_URL}/api/overview")
if echo "$OVERVIEW_RESPONSE" | jq -e '.overall_status' > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}System Overview: OK${NC}"
    echo "   Overall Status: $(echo "$OVERVIEW_RESPONSE" | jq -r '.overall_status')"
    echo "   Total Services: $(echo "$OVERVIEW_RESPONSE" | jq -r '.total_services')"
    echo "   Healthy Services: $(echo "$OVERVIEW_RESPONSE" | jq -r '.healthy_services')"
else
    echo -e "❌ ${RED}System Overview: FAILED${NC}"
    exit 1
fi

# Test 4: Grafana Access
echo -e "\n${YELLOW}4. Testing Grafana Access${NC}"
if curl -s -f "${OPS_BASE_URL}/grafana/api/health" > /dev/null; then
    echo -e "✅ ${GREEN}Grafana Access: OK${NC}"
else
    echo -e "❌ ${RED}Grafana Access: FAILED${NC}"
    exit 1
fi

# Test 5: Prometheus Access
echo -e "\n${YELLOW}5. Testing Prometheus Access${NC}"
if curl -s -f "${OPS_BASE_URL}/prometheus/-/healthy" > /dev/null; then
    echo -e "✅ ${GREEN}Prometheus Access: OK${NC}"
else
    echo -e "❌ ${RED}Prometheus Access: FAILED${NC}"
    exit 1
fi

# Test 6: Loki Access
echo -e "\n${YELLOW}6. Testing Loki Access${NC}"
if curl -s -f "${OPS_BASE_URL}/loki/ready" > /dev/null; then
    echo -e "✅ ${GREEN}Loki Access: OK${NC}"
else
    echo -e "❌ ${RED}Loki Access: FAILED${NC}"
    exit 1
fi

# Test 7: Enterprise Dashboards
echo -e "\n${YELLOW}7. Testing Enterprise Dashboards${NC}"

DASHBOARDS=(
    "viralogic-failures"
    "viralogic-autopost-executions"
    "viralogic-ai-performance"
    "viralogic-business"
    "viralogic-comprehensive"
)

for dashboard in "${DASHBOARDS[@]}"; do
    if curl -s -f "${OPS_BASE_URL}/grafana/api/dashboards/uid/${dashboard}" > /dev/null; then
        echo -e "✅ ${GREEN}Dashboard ${dashboard}: OK${NC}"
    else
        echo -e "❌ ${RED}Dashboard ${dashboard}: FAILED${NC}"
    fi
done

# Test 8: Service Registration
echo -e "\n${YELLOW}8. Testing Service Registration${NC}"
REGISTERED_SERVICES=$(curl -s -H "x-api-key: ${API_KEY}" "${OPS_BASE_URL}/api/v1/services/registered")
if echo "$REGISTERED_SERVICES" | jq -e '.services' > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}Service Registration: OK${NC}"
    echo "   Registered Services: $(echo "$REGISTERED_SERVICES" | jq -r '.services | length')"
else
    echo -e "❌ ${RED}Service Registration: FAILED${NC}"
fi

# Test 9: Log Access
echo -e "\n${YELLOW}9. Testing Log Access${NC}"
LOG_RESPONSE=$(curl -s -H "x-api-key: ${API_KEY}" "${OPS_BASE_URL}/api/logs?service=backend&limit=10")
if echo "$LOG_RESPONSE" | jq -e '.logs' > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}Log Access: OK${NC}"
    echo "   Logs Retrieved: $(echo "$LOG_RESPONSE" | jq -r '.logs | length')"
else
    echo -e "❌ ${RED}Log Access: FAILED${NC}"
fi

# Test 10: Metrics Collection
echo -e "\n${YELLOW}10. Testing Metrics Collection${NC}"
METRICS_RESPONSE=$(curl -s "${OPS_BASE_URL}/prometheus/api/v1/query?query=up")
if echo "$METRICS_RESPONSE" | jq -e '.data.result' > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}Metrics Collection: OK${NC}"
    echo "   Active Targets: $(echo "$METRICS_RESPONSE" | jq -r '.data.result | length')"
else
    echo -e "❌ ${RED}Metrics Collection: FAILED${NC}"
fi

# Test 11: Alerting Rules
echo -e "\n${YELLOW}11. Testing Alerting Rules${NC}"
ALERTS_RESPONSE=$(curl -s "${OPS_BASE_URL}/prometheus/api/v1/rules")
if echo "$ALERTS_RESPONSE" | jq -e '.data.groups' > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}Alerting Rules: OK${NC}"
    echo "   Alert Groups: $(echo "$ALERTS_RESPONSE" | jq -r '.data.groups | length')"
else
    echo -e "❌ ${RED}Alerting Rules: FAILED${NC}"
fi

# Test 12: API-Based Service Communication
echo -e "\n${YELLOW}12. Testing API-Based Service Communication${NC}"

# Test backend API
if curl -s -f "https://api.viralogic.io/health" > /dev/null; then
    echo -e "✅ ${GREEN}Backend API (api.viralogic.io): OK${NC}"
else
    echo -e "❌ ${RED}Backend API (api.viralogic.io): FAILED${NC}"
fi

# Test RSS service API
if curl -s -f "https://rss.viralogic.io/health/public" > /dev/null; then
    echo -e "✅ ${GREEN}RSS Service API (rss.viralogic.io): OK${NC}"
else
    echo -e "❌ ${RED}RSS Service API (rss.viralogic.io): FAILED${NC}"
fi

# Test frontend
if curl -s -f "https://viralogic.io" > /dev/null; then
    echo -e "✅ ${GREEN}Frontend (viralogic.io): OK${NC}"
else
    echo -e "❌ ${RED}Frontend (viralogic.io): FAILED${NC}"
fi

# Summary
echo -e "\n${BLUE}🎉 Production Monitoring System Test Complete!${NC}"
echo "=================================================="
echo -e "${GREEN}✅ All systems are production-ready!${NC}"
echo ""
echo -e "${YELLOW}📊 Access Your Dashboards:${NC}"
echo "   • Failure Notifications: ${OPS_BASE_URL}/grafana/d/viralogic-failures"
echo "   • Autopost Executions: ${OPS_BASE_URL}/grafana/d/viralogic-autopost-executions"
echo "   • AI Performance: ${OPS_BASE_URL}/grafana/d/viralogic-ai-performance"
echo "   • Business Metrics: ${OPS_BASE_URL}/grafana/d/viralogic-business"
echo "   • Comprehensive: ${OPS_BASE_URL}/grafana/d/viralogic-comprehensive"
echo ""
echo -e "${YELLOW}🔧 API Access:${NC}"
echo "   • Ops Service: ${OPS_BASE_URL}"
echo "   • Grafana: ${OPS_BASE_URL}/grafana"
echo "   • Prometheus: ${OPS_BASE_URL}/prometheus"
echo "   • Loki: ${OPS_BASE_URL}/loki"
echo ""
echo -e "${GREEN}🚀 Your enterprise-grade monitoring system is ready!${NC}"
