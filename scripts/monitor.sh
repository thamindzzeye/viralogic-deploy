#!/bin/bash

# Viralogic Health Monitoring Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$SCRIPT_DIR/../configs"

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check Docker services
check_docker_services() {
    print_status "Checking Docker services..."
    
    local compose_file="$CONFIGS_DIR/docker-compose.production.yml"
    
    if [[ -f "$compose_file" ]]; then
        echo ""
        echo "=== Main Application Services ==="
        docker-compose -f "$compose_file" ps
        
        # Check for unhealthy services
        local unhealthy=$(docker-compose -f "$compose_file" ps | grep -E "(unhealthy|exited|restarting)" || true)
        if [[ -n "$unhealthy" ]]; then
            print_warning "Some services are unhealthy:"
            echo "$unhealthy"
        else
            print_success "All main services are healthy"
        fi
    fi
    
    # Check RSS service if it exists
    local rss_compose_file="$CONFIGS_DIR/docker-compose.rss-service.yml"
    if [[ -f "$rss_compose_file" ]]; then
        echo ""
        echo "=== RSS Service ==="
        docker-compose -f "$rss_compose_file" ps
        
        local rss_unhealthy=$(docker-compose -f "$rss_compose_file" ps | grep -E "(unhealthy|exited|restarting)" || true)
        if [[ -n "$rss_unhealthy" ]]; then
            print_warning "Some RSS services are unhealthy:"
            echo "$rss_unhealthy"
        else
            print_success "All RSS services are healthy"
        fi
    fi
}

# Check system resources
check_system_resources() {
    print_status "Checking system resources..."
    
    echo ""
    echo "=== Docker System Resources ==="
    docker system df
    
    echo ""
    echo "=== System Memory Usage ==="
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        vm_stat | head -10
    else
        # Linux
        free -h
    fi
    
    echo ""
    echo "=== Disk Usage ==="
    df -h | head -10
}

# Check application health endpoints
check_health_endpoints() {
    print_status "Checking application health endpoints..."
    
    # Source environment variables to get domain names
    if [[ -f "$CONFIGS_DIR/.env.production" ]]; then
        source "$CONFIGS_DIR/.env.production"
    fi
    
    # Check main application health
    if [[ -n "$FRONTEND_URL" ]]; then
        echo ""
        echo "=== Frontend Health Check ==="
        if curl -s -f "$FRONTEND_URL/health" > /dev/null 2>&1; then
            print_success "Frontend is healthy"
        else
            print_warning "Frontend health check failed"
        fi
    fi
    
    if [[ -n "$BACKEND_URL" ]]; then
        echo ""
        echo "=== Backend Health Check ==="
        if curl -s -f "$BACKEND_URL/health" > /dev/null 2>&1; then
            print_success "Backend is healthy"
        else
            print_warning "Backend health check failed"
        fi
    fi
}

# Check Cloudflare tunnel
check_cloudflare_tunnel() {
    print_status "Checking Cloudflare tunnel..."
    
    if pgrep -f "cloudflared tunnel" > /dev/null; then
        print_success "Cloudflare tunnel is running"
    else
        print_warning "Cloudflare tunnel is not running"
    fi
}

# Check recent logs for errors
check_recent_logs() {
    print_status "Checking recent logs for errors..."
    
    local compose_file="$CONFIGS_DIR/docker-compose.production.yml"
    
    if [[ -f "$compose_file" ]]; then
        echo ""
        echo "=== Recent Error Logs (Last 50 lines) ==="
        docker-compose -f "$compose_file" logs --tail=50 | grep -i "error\|exception\|failed" || echo "No recent errors found"
    fi
}

# Main monitoring function
main() {
    echo "🔍 Viralogic Health Monitor"
    echo "=========================="
    
    check_docker_services
    check_system_resources
    check_health_endpoints
    check_cloudflare_tunnel
    check_recent_logs
    
    echo ""
    echo "✅ Health check completed"
}

# Run main function
main "$@"
