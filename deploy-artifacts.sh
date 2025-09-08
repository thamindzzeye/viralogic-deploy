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

# Check if help command is requested
if [[ "$1" == "help" || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 [COMMAND] [IMAGE_TAG] [DEPLOYMENT_DIR]"
    echo ""
    echo "Commands:"
    echo "  down                    Stop all containers"
    echo "  help, -h, --help        Show this help message"
    echo "  (no command)            Deploy containers (default)"
    echo ""
    echo "Arguments:"
    echo "  IMAGE_TAG               Docker image tag (default: local)"
    echo "  DEPLOYMENT_DIR          Deployment directory (default: ./viralogic-deploy)"
    echo ""
    echo "Examples:"
    echo "  $0                      Deploy with default settings"
    echo "  $0 down                 Stop all containers"
    echo "  $0 production           Deploy with 'production' image tag"
    echo "  $0 local /custom/path   Deploy with custom deployment directory"
    exit 0
fi

# Check if down command is requested
if [[ "$1" == "down" ]]; then
    print_status "🛑 Stopping all containers..."
    
    # Stop main application containers
    print_status "Stopping main application containers..."
    if docker-compose -f Viralogic/docker-compose-main-local.yml down --remove-orphans; then
        print_success "Main application containers stopped"
    else
        print_warning "Some main application containers may not have stopped cleanly"
    fi
    
# Stop RSS service containers
print_status "Stopping RSS service containers..."
if docker-compose -f rss-service/docker-compose-rss-local.yml down --remove-orphans; then
    print_success "RSS service containers stopped"
else
    print_warning "Some RSS service containers may not have stopped cleanly"
fi

# Stop Ops service containers
print_status "Stopping Ops service containers..."
if docker-compose -f ops-service/docker-compose-ops-local.yml down --remove-orphans; then
    print_success "Ops service containers stopped"
else
    print_warning "Some ops service containers may not have stopped cleanly"
fi
    
    print_success "🎉 All containers stopped successfully!"
    exit 0
fi

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

if [[ ! -f "output/images/ops-service-$IMAGE_TAG.tar.gz" ]]; then
    print_error "Ops service image not found: output/images/ops-service-$IMAGE_TAG.tar.gz"
    exit 1
fi

# Check for required environment files
print_status "Checking environment files..."

if [[ ! -f "Viralogic/.env" ]]; then
    print_error "Viralogic/.env file not found"
    print_status "Please ensure Viralogic/.env exists with all required environment variables"
    exit 1
fi

if [[ ! -f "rss-service/.env" ]]; then
    print_error "rss-service/.env file not found"
    print_status "Please ensure rss-service/.env exists with all required environment variables"
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

print_status "Loading Ops service image..."
docker load < "output/images/ops-service-$IMAGE_TAG.tar.gz"

print_success "All images loaded successfully!"

# Show loaded images
print_status "Loaded images:"
docker images | grep viralogic

# Load environment variables for Docker Compose
print_status "Loading environment variables..."
export REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" Viralogic/.env | cut -d'=' -f2)
export RSS_REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" rss-service/.env | cut -d'=' -f2)

# Deploy containers automatically
print_status "🚀 Deploying containers..."

# Stop any existing containers first
print_status "Stopping existing containers..."
docker-compose -f Viralogic/docker-compose-main-local.yml down --remove-orphans 2>/dev/null || true
docker-compose -f rss-service/docker-compose-rss-local.yml down --remove-orphans 2>/dev/null || true
docker-compose -f ops-service/docker-compose-ops-local.yml down --remove-orphans 2>/dev/null || true

# Deploy main application
print_status "Deploying main application..."
if docker-compose -f Viralogic/docker-compose-main-local.yml up -d; then
    print_success "Main application deployed successfully"
else
    print_error "Failed to deploy main application"
    exit 1
fi

# Deploy RSS service
print_status "Deploying RSS service..."
if docker-compose -f rss-service/docker-compose-rss-local.yml up -d; then
    print_success "RSS service deployed successfully"
else
    print_error "Failed to deploy RSS service"
    exit 1
fi

# Deploy Ops service
print_status "Deploying Ops service..."
if docker-compose -f ops-service/docker-compose-ops-local.yml up -d; then
    print_success "Ops service deployed successfully"
else
    print_error "Failed to deploy ops service"
    exit 1
fi

# Wait for services to start
print_status "Waiting for services to start..."
sleep 10

# =============================================================================
# DATABASE MIGRATION PHASE
# =============================================================================
print_status "Running database migrations..."

# Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 10

# Run migrations on main application
print_status "Running main application migrations..."
if docker-compose -f Viralogic/docker-compose-main-local.yml exec -T backend python -m alembic upgrade head; then
    print_success "Main application migrations completed"
else
    print_error "Failed to run main application migrations"
    print_status "Checking migration status..."
    docker-compose -f Viralogic/docker-compose-main-local.yml exec -T backend python -m alembic current
    exit 1
fi

# Run migrations on RSS service
print_status "Running RSS service migrations..."
if docker-compose -f rss-service/docker-compose-rss-local.yml exec -T rss-service python -m alembic upgrade head; then
    print_success "RSS service migrations completed"
else
    print_error "Failed to run RSS service migrations"
    print_status "Checking migration status..."
    docker-compose -f rss-service/docker-compose-rss-local.yml exec -T rss-service python -m alembic current
    exit 1
fi

# Show deployment status
print_status "📊 Deployment Status:"
docker-compose -f Viralogic/docker-compose-main-local.yml -f rss-service/docker-compose-rss-local.yml -f ops-service/docker-compose-ops-local.yml ps

print_success "🎉 Artifact deployment and container startup completed successfully!"
echo ""
print_status "💡 Benefits:"
print_status "  ✅ Instant deployment (no build time)"
print_status "  ✅ Consistent builds across environments"
print_status "  ✅ Faster iteration cycles"
print_status "  ✅ Automatic container startup"
