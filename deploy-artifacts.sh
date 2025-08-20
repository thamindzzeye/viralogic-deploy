#!/bin/bash

# Server-side artifact deployment script
# This script should be copied to the server along with the artifacts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
IMAGE_TAG=${1:-local}
DEPLOYMENT_DIR=${2:-./viralogic-deploy}

print_status "Starting artifact deployment..."
print_status "Image tag: $IMAGE_TAG"
print_status "Deployment directory: $DEPLOYMENT_DIR"

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

if [[ ! -d "output/images" ]]; then
    print_error "output/images directory not found"
    print_status "Please ensure you have copied the output folder to this directory"
    exit 1
fi

if [[ ! -f "output/images/backend-$IMAGE_TAG.tar.gz" ]]; then
    print_error "Backend image not found: output/images/backend-$IMAGE_TAG.tar.gz"
    exit 1
fi

if [[ ! -f "output/images/frontend-$IMAGE_TAG.tar.gz" ]]; then
    print_error "Frontend image not found: output/images/frontend-$IMAGE_TAG.tar.gz"
    exit 1
fi

if [[ ! -f "output/images/rss-service-$IMAGE_TAG.tar.gz" ]]; then
    print_error "RSS service image not found: output/images/rss-service-$IMAGE_TAG.tar.gz"
    exit 1
fi

print_success "All required files found"

# Load Docker images
print_status "Loading Docker images..."

print_status "Loading backend image..."
docker load < "output/images/backend-$IMAGE_TAG.tar.gz"

print_status "Loading frontend image..."
docker load < "output/images/frontend-$IMAGE_TAG.tar.gz"

print_status "Loading RSS service image..."
docker load < "output/images/rss-service-$IMAGE_TAG.tar.gz"

print_success "All images loaded successfully!"

# Show loaded images
print_status "Loaded images:"
docker images | grep viralogic

# Create docker-compose override file
print_status "Creating docker-compose override file..."

cat > "docker-compose-artifacts.yml" << EOF
# Docker Compose override for artifact deployment
# Generated on: $(date)

services:
  backend:
    image: viralogic/backend:$IMAGE_TAG

  frontend:
    image: viralogic/frontend:$IMAGE_TAG

  celeryworker:
    image: viralogic/backend:$IMAGE_TAG

  celerybeat:
    image: viralogic/backend:$IMAGE_TAG

  rss-service:
    image: viralogic/rss-service:$IMAGE_TAG

  rss-celery-worker:
    image: viralogic/rss-service:$IMAGE_TAG

  rss-celery-beat:
    image: viralogic/rss-service:$IMAGE_TAG
EOF

print_success "Docker Compose override created: docker-compose-artifacts.yml"

# Copy override to deployment directory if specified
if [[ -n "$DEPLOYMENT_DIR" && -d "$DEPLOYMENT_DIR" ]]; then
    print_status "Copying override to deployment directory..."
    cp "docker-compose-artifacts.yml" "$DEPLOYMENT_DIR/"
    print_success "Override copied to $DEPLOYMENT_DIR/"
fi

print_success "🎉 Artifact deployment completed successfully!"
echo ""
print_status "📋 Next steps:"
print_status "  1. Navigate to your deployment directory:"
print_status "     cd $DEPLOYMENT_DIR"
print_status ""
print_status "  2. Deploy main application:"
print_status "     docker-compose -f Viralogic/docker-compose-main.yml -f docker-compose-artifacts.yml up -d"
print_status ""
print_status "  3. Deploy RSS service:"
print_status "     docker-compose -f rss-service/docker-compose-rss.yml -f docker-compose-artifacts.yml up -d"
echo ""
print_status "💡 Benefits:"
print_status "  ✅ Instant deployment (no build time)"
print_status "  ✅ Consistent builds across environments"
print_status "  ✅ Faster iteration cycles"
