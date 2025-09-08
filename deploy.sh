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

# Check if this is a stop command
if [[ "$1" == "stop" ]]; then
    print_status "Stopping all Viralogic services..."
    
    cd $SCRIPT_DIR
    
    print_status "Stopping main application services..."
    docker-compose -f Viralogic/docker-compose-main.yml down --remove-orphans
    
print_status "Stopping RSS service..."
docker-compose -f rss-service/docker-compose-rss.yml down --remove-orphans

print_status "Stopping Ops service..."
docker-compose -f ops-service/docker-compose-ops.yml down --remove-orphans

print_success "All services stopped successfully!"
    exit 0
fi

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

if [[ ! -f "$SCRIPT_DIR/Viralogic/docker-compose-main.yml" ]]; then
    print_error "Viralogic/docker-compose-main.yml not found"
    exit 1
fi

if [[ ! -f "$SCRIPT_DIR/rss-service/docker-compose-rss.yml" ]]; then
    print_error "rss-service/docker-compose-rss.yml not found"
    exit 1
fi

if [[ ! -f "$SCRIPT_DIR/ops-service/docker-compose-ops.yml" ]]; then
    print_error "ops-service/docker-compose-ops.yml not found"
    exit 1
fi

if [[ ! -f "$SCRIPT_DIR/Viralogic/cloudflared/viralogic-production-tunnel.json" ]]; then
    print_error "Main cloudflare tunnel JSON not found: Viralogic/cloudflared/viralogic-production-tunnel.json"
    print_status "Please create this file with your tunnel credentials"
    exit 1
fi

if [[ ! -f "$SCRIPT_DIR/rss-service/cloudflared/viralogic-rss-production-tunnel.json" ]]; then
    print_error "RSS cloudflare tunnel JSON not found: rss-service/cloudflared/viralogic-rss-production-tunnel.json"
    print_status "Please create this file with your tunnel credentials"
    exit 1
fi

if [[ ! -f "$SCRIPT_DIR/ops-service/cloudflared/viralogic-ops-production-tunnel.json" ]]; then
    print_error "Ops cloudflare tunnel JSON not found: ops-service/cloudflared/viralogic-ops-production-tunnel.json"
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

if [[ ! -f "$SCRIPT_DIR/ops-service/.env" ]]; then
    print_error "ops-service/.env file not found"
    print_status "Please create a .env file in the ops-service directory with all required environment variables"
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

print_status "Pulling Ops service image..."
if ! docker pull ghcr.io/$GITHUB_REPOSITORY/ops-service:$IMAGE_TAG; then
    print_error "Failed to pull ops service image"
    exit 1
fi

print_success "All images pulled successfully"

# Navigate to script directory
cd $SCRIPT_DIR

# =============================================================================
# CLEANUP PHASE - Stop all services first
# =============================================================================
print_status "Starting cleanup phase..."

print_status "Stopping main application services..."
if docker-compose -f Viralogic/docker-compose-main.yml down --remove-orphans; then
    print_success "Main application services stopped"
else
    print_warning "Some main application services may not have stopped cleanly"
fi

print_status "Stopping RSS service..."
if docker-compose -f rss-service/docker-compose-rss.yml down --remove-orphans; then
    print_success "RSS service stopped"
else
    print_warning "Some RSS services may not have stopped cleanly"
fi

print_status "Stopping Ops service..."
if docker-compose -f ops-service/docker-compose-ops.yml down --remove-orphans; then
    print_success "Ops service stopped"
else
    print_warning "Some ops services may not have stopped cleanly"
fi

# Clean up unused Docker resources
print_status "Cleaning up unused Docker resources..."
docker system prune -f --volumes

# =============================================================================
# DEPLOYMENT PHASE
# =============================================================================
print_status "Starting deployment phase..."

# Deploy main application
print_status "Deploying main application..."
if docker-compose -f Viralogic/docker-compose-main.yml up -d; then
    print_success "Main application deployed successfully"
else
    print_error "Failed to deploy main application"
    exit 1
fi

# Deploy RSS service
print_status "Deploying RSS service..."
if docker-compose -f rss-service/docker-compose-rss.yml up -d; then
    print_success "RSS service deployed successfully"
else
    print_error "Failed to deploy RSS service"
    exit 1
fi

# Deploy Ops service
print_status "Deploying Ops service..."
if docker-compose -f ops-service/docker-compose-ops.yml up -d; then
    print_success "Ops service deployed successfully"
else
    print_error "Failed to deploy ops service"
    exit 1
fi

# =============================================================================
# DATABASE MIGRATION PHASE
# =============================================================================
print_status "Running database migrations..."

# Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 20

# Run migrations on main application
print_status "Running main application migrations..."
if docker-compose -f Viralogic/docker-compose-main.yml exec -T backend python -m alembic upgrade head; then
    print_success "Main application migrations completed"
else
    print_error "Failed to run main application migrations"
    print_status "Checking migration status..."
    docker-compose -f Viralogic/docker-compose-main.yml exec -T backend python -m alembic current
    exit 1
fi

# Run migrations on RSS service
print_status "Running RSS service migrations..."
if docker-compose -f rss-service/docker-compose-rss.yml exec -T rss-service python -m alembic upgrade head; then
    print_success "RSS service migrations completed"
else
    print_error "Failed to run RSS service migrations"
    print_status "Checking migration status..."
    docker-compose -f rss-service/docker-compose-rss.yml exec -T rss-service python -m alembic current
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

# Check Ops service
check_health "Ops Grafana" "http://localhost:3000/api/health"
check_health "Ops Loki" "http://localhost:3100/ready"

# =============================================================================
# FINAL STATUS & SUMMARY
# =============================================================================
print_status "Service status:"
print_status "Main application services:"
docker-compose -f Viralogic/docker-compose-main.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

print_status "RSS service:"
docker-compose -f rss-service/docker-compose-rss.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

print_status "Ops service:"
docker-compose -f ops-service/docker-compose-ops.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

print_success "🎉 Deployment completed successfully!"
echo ""
print_status "🌐 Your application is now available at:"
print_status "  📱 Frontend: https://viralogic.io"
print_status "  🔌 API: https://api.viralogic.io"
print_status "  📰 RSS Service: https://rss.viralogic.io"
print_status "  📊 Ops Dashboard: https://ops.viralogic.io"
echo ""
print_status "📋 Useful commands:"
print_status "  View main app logs: docker-compose -f Viralogic/docker-compose-main.yml logs -f"
print_status "  View RSS service logs: docker-compose -f rss-service/docker-compose-rss.yml logs -f"
print_status "  View Ops service logs: docker-compose -f ops-service/docker-compose-ops.yml logs -f"
print_status "  View all services: docker-compose -f Viralogic/docker-compose-main.yml -f rss-service/docker-compose-rss.yml -f ops-service/docker-compose-ops.yml ps"
print_status "  Stop all services: ./deploy.sh stop"
echo ""
print_status "🔍 Health check endpoints:"
print_status "  Backend: https://api.viralogic.io/health"
print_status "  RSS Service: https://rss.viralogic.io/health/public"
print_status "  RSS Flower: https://rss.viralogic.io:1727"
print_status "  Ops Grafana: https://ops.viralogic.io/api/health"
print_status "  Ops Loki: https://ops.viralogic.io:3100/ready"

