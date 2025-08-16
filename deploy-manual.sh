#!/bin/bash

# Manual Deployment Script for Viralogic
# Run this on your production server to deploy the latest images

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$SCRIPT_DIR/configs"

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

# Default values
IMAGE_TAG=${1:-latest}
GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-thamindzzeye/Viralogic}

print_status "Starting manual deployment..."
print_status "Image tag: $IMAGE_TAG"
print_status "Repository: $GITHUB_REPOSITORY"

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

if [[ ! -f "$CONFIGS_DIR/.env.production" ]]; then
    print_error "Environment file not found: $CONFIGS_DIR/.env.production"
    print_status "Please copy env.production.example and configure it:"
    print_status "cp $CONFIGS_DIR/env.production.example $CONFIGS_DIR/.env.production"
    exit 1
fi

print_success "Prerequisites check passed"

# Pull latest deploy code
print_status "Pulling latest deployment code..."
git pull origin main

# Pull latest Docker images
print_status "Pulling latest Docker images..."

print_status "Pulling backend image..."
docker pull ghcr.io/$GITHUB_REPOSITORY/backend:$IMAGE_TAG

print_status "Pulling frontend image..."
docker pull ghcr.io/$GITHUB_REPOSITORY/frontend:$IMAGE_TAG

print_status "Pulling RSS service image..."
docker pull ghcr.io/$GITHUB_REPOSITORY/rss-service:$IMAGE_TAG

print_success "All images pulled successfully"

# Deploy main application
print_status "Deploying main application..."
cd $CONFIGS_DIR
export GITHUB_REPOSITORY=$GITHUB_REPOSITORY
export IMAGE_TAG=$IMAGE_TAG

docker-compose -f docker-compose.main-app.yml down
docker-compose -f docker-compose.main-app.yml up -d

print_success "Main application deployed"

# Deploy RSS service
print_status "Deploying RSS service..."
docker-compose -f docker-compose.rss-service.yml down
docker-compose -f docker-compose.rss-service.yml up -d

print_success "RSS service deployed"

# Wait for services to start
print_status "Waiting for services to start..."
sleep 30

# Health checks
print_status "Running health checks..."

# Check main app
if curl -f http://localhost:3000 > /dev/null 2>&1; then
    print_success "Frontend health check passed"
else
    print_warning "Frontend health check failed"
fi

# Check backend
if curl -f http://localhost:8000/health > /dev/null 2>&1; then
    print_success "Backend health check passed"
else
    print_warning "Backend health check failed"
fi

# Check RSS service
if curl -f http://localhost:8001/health/public > /dev/null 2>&1; then
    print_success "RSS service health check passed"
else
    print_warning "RSS service health check failed"
fi

# Show service status
print_status "Service status:"
docker-compose -f docker-compose.production.yml ps
docker-compose -f docker-compose.rss-service.yml ps

print_success "Manual deployment completed!"
print_status "Your application should be available at:"
print_status "  Frontend: https://viralogic.io"
print_status "  API: https://api.viralogic.io"
print_status "  RSS Service: https://rss.viralogic.io"
