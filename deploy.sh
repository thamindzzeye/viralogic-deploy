#!/bin/bash

# Viralogic Deployment Script
# Simple, production-ready deployment for the Viralogic platform

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



# Default values
IMAGE_TAG=${1:-main}
GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-thamindzzeye/viralogic}

print_status "Starting Viralogic deployment..."
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

print_success "Prerequisites check passed"

# Check for required files
print_status "Checking required files..."

if [[ ! -f "$SCRIPT_DIR/docker-compose-main.yml" ]]; then
    print_error "docker-compose-main.yml not found"
    exit 1
fi

if [[ ! -f "$SCRIPT_DIR/docker-compose-rss.yml" ]]; then
    print_error "docker-compose-rss.yml not found"
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

# Check for .env file
if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
    print_error ".env file not found"
    print_status "Please create a .env file in the deployment directory with all required environment variables"
    exit 1
fi

print_success "All required files found"

# Authenticate with GitHub Container Registry
print_status "Starting GitHub authentication..."

# Prompt for GitHub token
echo ""
echo -e "${BLUE}[INFO]${NC} ==========================================="
echo -e "${BLUE}[INFO]${NC} GITHUB AUTHENTICATION REQUIRED"
echo -e "${BLUE}[INFO]${NC} ==========================================="
echo -e "${BLUE}[INFO]${NC} Please enter your GitHub Personal Access Token below:"
echo -e "${YELLOW}[NOTE]${NC} The token will not be displayed as you type for security"
echo -e "${BLUE}[INFO]${NC} Token: "
read -s GITHUB_TOKEN
echo  # Add newline after hidden input

# Prompt for GitHub username
echo ""
echo -e "${BLUE}[INFO]${NC} Please enter your GitHub username:"
echo -e "${BLUE}[INFO]${NC} Username: "
read GITHUB_USERNAME

# Authenticate
print_status "Authenticating with GitHub Container Registry..."
if echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin; then
    print_success "Successfully authenticated with GitHub Container Registry"
else
    print_error "Failed to authenticate with GitHub Container Registry"
    exit 1
fi

# Pull latest Docker images
print_status "Pulling latest Docker images..."

print_status "Pulling backend image..."
if ! docker pull ghcr.io/$GITHUB_REPOSITORY/backend:$IMAGE_TAG; then
    print_error "Failed to pull backend image"
    exit 1
fi

print_status "Pulling frontend image..."
if ! docker pull ghcr.io/$GITHUB_REPOSITORY/frontend:$IMAGE_TAG; then
    print_error "Failed to pull frontend image"
    exit 1
fi

print_status "Pulling RSS service image..."
if ! docker pull ghcr.io/$GITHUB_REPOSITORY/rss-service:$IMAGE_TAG; then
    print_error "Failed to pull RSS service image"
    exit 1
fi

print_success "All images pulled successfully"

# Deploy main application
print_status "Deploying main application..."
cd $SCRIPT_DIR

docker-compose -f docker-compose-main.yml down
docker-compose -f docker-compose-main.yml up -d

print_success "Main application deployed"

# Deploy RSS service
print_status "Deploying RSS service..."
docker-compose -f docker-compose-rss.yml down
docker-compose -f docker-compose-rss.yml up -d

print_success "RSS service deployed"

# Wait for services to start
print_status "Waiting for services to start..."
sleep 30

# Health checks
print_status "Running health checks..."

# Check main app backend
if curl -f http://localhost:1720/health > /dev/null 2>&1; then
    print_success "Backend health check passed"
else
    print_warning "Backend health check failed (port 1720)"
fi

# Check main app frontend
if curl -f http://localhost:1721 > /dev/null 2>&1; then
    print_success "Frontend health check passed"
else
    print_warning "Frontend health check failed (port 1721)"
fi

# Check RSS service
if curl -f http://localhost:1722/health/public > /dev/null 2>&1; then
    print_success "RSS service health check passed"
else
    print_warning "RSS service health check failed (port 1722)"
fi

# Check RSS Flower monitoring
if curl -f http://localhost:1727 > /dev/null 2>&1; then
    print_success "RSS Flower monitoring health check passed"
else
    print_warning "RSS Flower monitoring health check failed (port 1727)"
fi

# Show service status
print_status "Service status:"
docker-compose -f docker-compose-main.yml ps
docker-compose -f docker-compose-rss.yml ps

print_success "Deployment completed!"
print_status "Your application should be available at:"
print_status "  Frontend: https://viralogic.tbdv.org"
print_status "  API: https://viralogic-api.tbdv.org"
print_status "  RSS Service: https://rss.viralogic.io"

print_status "To view logs:"
print_status "  Main app: docker-compose -f docker-compose-main.yml logs -f"
print_status "  RSS service: docker-compose -f docker-compose-rss.yml logs -f"

