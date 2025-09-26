#!/bin/bash

# Viralogic Staging Deployment Script
# Hot reload development environment

set -e

echo "🚀 Starting Viralogic Staging Deployment"
echo "========================================"

# Check if we're in the right directory
if [ ! -f "deploy-staging.sh" ]; then
    echo "❌ Please run this script from the viralogic-deploy directory"
    exit 1
fi

# Function to deploy a service
deploy_service() {
    local service_name=$1
    local compose_file=$2
    
    echo ""
    echo "📦 Deploying $service_name..."
    echo "Using: $compose_file"
    
    cd "$service_name"
    
    # Stop existing staging containers
    echo "🛑 Stopping existing staging containers..."
    docker-compose -f "$compose_file" down --remove-orphans || true
    
    # Build and start staging containers
    echo "🔨 Building and starting staging containers..."
    docker-compose -f "$compose_file" up --build -d
    
    echo "✅ $service_name staging deployment complete!"
    
    cd ..
}

# Deploy all services
echo "🎯 Deploying all services in staging mode..."

# 1. Deploy RSS Service
deploy_service "rss-service" "docker-compose-rss-staging.yml"

# 2. Deploy Main Viralogic App
deploy_service "Viralogic" "docker-compose-main-staging.yml"

# 3. Deploy Ops Service
deploy_service "ops-service" "docker-compose-ops-staging.yml"

echo ""
echo "🎉 All staging services deployed!"
echo ""
echo "📊 Service URLs:"
echo "  • Main App: http://localhost:1720 (backend), http://localhost:1721 (frontend)"
echo "  • RSS Service: http://localhost:1722"
echo "  • Ops Service: http://localhost:1825"
echo "  • Flower: http://localhost:5555"
echo "  • Grafana: http://localhost:1820"
echo ""
echo "🔥 Hot Reload Enabled:"
echo "  • Code changes will automatically reload"
echo "  • No need to rebuild containers"
echo "  • Just save files and changes are live!"
echo ""
echo "🛑 To stop staging:"
echo "  ./stop-staging.sh"

