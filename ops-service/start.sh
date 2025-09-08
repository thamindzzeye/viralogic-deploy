#!/bin/bash

# Ops Service Startup Script
# This script starts the centralized logging and monitoring service

set -e

echo "🚀 Starting Viralogic Ops Service..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Create necessary directories
echo "📁 Creating configuration directories..."
mkdir -p config/loki
mkdir -p config/promtail
mkdir -p config/grafana/provisioning/datasources
mkdir -p config/grafana/provisioning/dashboards
mkdir -p config/grafana/dashboards

# Start the services
echo "🐳 Starting containers..."
docker-compose up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check service health
echo "🔍 Checking service health..."

# Check Loki
if curl -f http://localhost:3100/ready > /dev/null 2>&1; then
    echo "✅ Loki is healthy"
else
    echo "❌ Loki health check failed"
fi

# Check Grafana
if curl -f http://localhost:3000/api/health > /dev/null 2>&1; then
    echo "✅ Grafana is healthy"
else
    echo "❌ Grafana health check failed"
fi

echo ""
echo "🎉 Ops Service is starting up!"
echo ""
echo "📊 Access Points:"
echo "   Grafana Dashboard: http://localhost:3000"
echo "   Loki API: http://localhost:3100"
echo "   Promtail: http://localhost:9080"
echo ""
echo "🔑 Default Credentials:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "📝 Next Steps:"
echo "   1. Open Grafana at http://localhost:3000"
echo "   2. Log in with admin/admin123"
echo "   3. The 'Viralogic Logs Overview' dashboard should be available"
echo "   4. Configure your existing services to send logs to this system"
echo ""
echo "🛑 To stop: docker-compose down"
echo "📋 To view logs: docker-compose logs -f"
