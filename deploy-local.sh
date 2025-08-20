#!/bin/bash

# Viralogic Local Deployment Script
# Builds and deploys from local source code (bypasses GitHub Container Registry)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to print colored output
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

# Check if this is a stop command
if [[ "$1" == "stop" ]]; then
    print_status "Stopping all Viralogic services..."
    
    cd $SCRIPT_DIR
    
    print_status "Stopping main application services..."
    docker-compose -f Viralogic/docker-compose-main-local.yml down --remove-orphans
    
    print_status "Stopping RSS service..."
    docker-compose -f rss-service/docker-compose-rss-local.yml down --remove-orphans
    
    print_success "All services stopped successfully!"
    exit 0
fi

print_status "Starting Viralogic LOCAL deployment..."
print_status "Building from source code..."

# Check prerequisites
print_status "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed"
    exit 1
fi

print_success "Prerequisites check passed"

# Check for required files
print_status "Checking required files..."

if [[ ! -f "$SCRIPT_DIR/Viralogic/docker-compose-main-local.yml" ]]; then
    print_error "Viralogic/docker-compose-main-local.yml not found"
    exit 1
fi

if [[ ! -f "$SCRIPT_DIR/rss-service/docker-compose-rss-local.yml" ]]; then
    print_error "rss-service/docker-compose-rss-local.yml not found"
    exit 1
fi

if [[ ! -f "$SCRIPT_DIR/cloudflared/viralogic-production-tunnel.json" ]]; then
    print_error "Main cloudflare tunnel JSON not found: cloudflared/viralogic-production-tunnel.json"
    print_status "Please create this file with your tunnel credentials"
    exit 1
fi

if [[ ! -f "$SCRIPT_DIR/cloudflared/viralogic-rss-production-tunnel.json" ]]; then
    print_error "RSS cloudflare tunnel JSON not found: cloudflared/viralogic-rss-production-tunnel.json"
    print_status "Please create this file with your tunnel credentials"
    exit 1
fi

# Check for .env files
if [[ ! -f "$SCRIPT_DIR/Viralogic/.env" ]]; then
    print_error "Viralogic/.env file not found"
    print_status "Please create a .env file in the Viralogic directory with all required environment variables"
    exit 1
fi

if [[ ! -f "$SCRIPT_DIR/rss-service/.env" ]]; then
    print_error "rss-service/.env file not found"
    print_status "Please create a .env file in the rss-service directory with all required environment variables"
    exit 1
fi

# Check for source code
if [[ ! -d "$SCRIPT_DIR/../Viralogic" ]]; then
    print_error "Viralogic source code not found at ../Viralogic"
    print_status "Please ensure the Viralogic repository is cloned at the same level as viralogic-deploy"
    exit 1
fi

print_success "All required files found"

# Navigate to script directory
cd $SCRIPT_DIR

# =============================================================================
# CLEANUP PHASE - Stop all services first
# =============================================================================
print_status "Starting cleanup phase..."

print_status "Stopping main application services..."
if docker-compose -f Viralogic/docker-compose-main-local.yml down --remove-orphans; then
    print_success "Main application services stopped"
else
    print_warning "Some main application services may not have stopped cleanly"
fi

print_status "Stopping RSS service..."
if docker-compose -f rss-service/docker-compose-rss-local.yml down --remove-orphans; then
    print_success "RSS service stopped"
else
    print_warning "Some RSS services may not have stopped cleanly"
fi

# Clean up unused Docker resources
print_status "Cleaning up unused Docker resources..."
docker system prune -f --volumes

# =============================================================================
# BUILD & DEPLOYMENT PHASE
# =============================================================================
print_status "Starting build and deployment phase..."

# Build and deploy main application
print_status "Building and deploying main application..."
if docker-compose -f Viralogic/docker-compose-main-local.yml up -d --build; then
    print_success "Main application built and deployed successfully"
else
    print_error "Failed to build and deploy main application"
    exit 1
fi

# Build and deploy RSS service
print_status "Building and deploying RSS service..."
if docker-compose -f rss-service/docker-compose-rss-local.yml up -d --build; then
    print_success "RSS service built and deployed successfully"
else
    print_error "Failed to build and deploy RSS service"
    exit 1
fi

# =============================================================================
# HEALTH CHECK PHASE
# =============================================================================
print_status "Waiting for services to start..."
sleep 30

print_status "Running health checks..."

# Function to check health with retries
check_health() {
    local service_name=$1
    local url=$2
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s --max-time 10 "$url" > /dev/null 2>&1; then
            print_success "$service_name health check passed"
            return 0
        else
            if [ $attempt -eq $max_attempts ]; then
                print_warning "$service_name health check failed after $max_attempts attempts"
                return 1
            else
                print_status "Attempt $attempt/$max_attempts: $service_name not ready, retrying in 10 seconds..."
                sleep 10
                attempt=$((attempt + 1))
            fi
        fi
    done
}

# Check main app backend
check_health "Backend API" "http://localhost:1720/health"

# Check main app frontend
check_health "Frontend" "http://localhost:1721"

# Check RSS service
check_health "RSS Service" "http://localhost:1722/health/public"

# Check RSS Flower monitoring
check_health "RSS Flower" "http://localhost:1727"

# =============================================================================
# FINAL STATUS & SUMMARY
# =============================================================================
print_status "Service status:"
print_status "Main application services:"
docker-compose -f Viralogic/docker-compose-main-local.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

print_status "RSS service:"
docker-compose -f rss-service/docker-compose-rss-local.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

print_success "🎉 LOCAL deployment completed successfully!"
echo ""
print_status "🌐 Your application is now available at:"
print_status "  📱 Frontend: https://viralogic.io"
print_status "  🔌 API: https://api.viralogic.io"
print_status "  📰 RSS Service: https://rss.viralogic.io"
echo ""
print_status "📋 Useful commands:"
print_status "  View main app logs: docker-compose -f Viralogic/docker-compose-main-local.yml logs -f"
print_status "  View RSS service logs: docker-compose -f rss-service/docker-compose-rss-local.yml logs -f"
print_status "  View all services: docker-compose -f Viralogic/docker-compose-main-local.yml -f rss-service/docker-compose-rss-local.yml ps"
print_status "  Stop all services: ./deploy-local.sh stop"
print_status "  Rebuild specific service: docker-compose -f Viralogic/docker-compose-main-local.yml up -d --build backend"
echo ""
print_status "🔍 Health check endpoints:"
print_status "  Backend: https://api.viralogic.io/health"
print_status "  RSS Service: https://rss.viralogic.io/health/public"
print_status "  RSS Flower: https://rss.viralogic.io:1727"
echo ""
print_status "💡 Local Build Benefits:"
print_status "  ✅ No GitHub Container Registry dependency"
print_status "  ✅ Faster iteration (no 1.5 hour builds)"
print_status "  ✅ Immediate testing of changes"
print_status "  ✅ Full control over build process"
