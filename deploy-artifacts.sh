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

# Check for required environment files
print_status "Checking environment files..."

if [[ ! -f "main/.env" ]]; then
    print_error "main/.env file not found"
    print_status "Please ensure main/.env exists with all required environment variables"
    exit 1
fi

if [[ ! -f "rss/.env" ]]; then
    print_error "rss/.env file not found"
    print_status "Please ensure rss/.env exists with all required environment variables"
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

# Load environment variables for Docker Compose
print_status "Loading environment variables..."
export REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" main/.env | cut -d'=' -f2)
export RSS_REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" rss/.env | cut -d'=' -f2)

# Show loaded images
print_status "Loaded images:"
docker images | grep viralogic



print_success "🎉 Artifact deployment completed successfully!"
echo ""
print_status "📋 Next steps:"
print_status "  1. Navigate to your deployment directory:"
print_status "     cd $DEPLOYMENT_DIR"
print_status ""
print_status "  2. Deploy main application:"
print_status "     docker-compose -f docker-compose-main-local.yml up -d"
print_status ""
print_status "  3. Deploy RSS service:"
print_status "     docker-compose -f docker-compose-rss-local.yml up -d"
echo ""
print_status "💡 Benefits:"
print_status "  ✅ Instant deployment (no build time)"
print_status "  ✅ Consistent builds across environments"
print_status "  ✅ Faster iteration cycles"
