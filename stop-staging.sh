#!/bin/bash

# Stop Viralogic Staging Services

set -e

echo "🛑 Stopping Viralogic Staging Services"
echo "======================================"

# Function to stop a service
stop_service() {
    local service_name=$1
    local compose_file=$2
    
    echo ""
    echo "🛑 Stopping $service_name..."
    
    cd "$service_name"
    
    # Stop staging containers
    docker-compose -f "$compose_file" down --remove-orphans || true
    
    echo "✅ $service_name stopped!"
    
    cd ..
}

# Stop all services
echo "🎯 Stopping all staging services..."

# 1. Stop RSS Service
stop_service "rss-service" "docker-compose-rss-staging.yml"

# 2. Stop Main Viralogic App
stop_service "Viralogic" "docker-compose-main-staging.yml"

# 3. Stop Ops Service
stop_service "ops-service" "docker-compose-ops-staging.yml"

echo ""
echo "✅ All staging services stopped!"
echo ""
echo "💡 To restart staging:"
echo "  ./deploy-staging.sh"

