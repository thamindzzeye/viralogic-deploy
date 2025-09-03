#!/bin/bash

# Viralogic Database Migration Script
# Run this script to execute database migrations manually

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

print_status "🚀 Viralogic Database Migration Script"
print_status "This script will run database migrations for both main app and RSS service"

# Check if services are running
print_status "Checking if services are running..."

# Check main application
if ! docker ps | grep -q "viralogic-deploy_backend"; then
    print_error "Main application backend container not running"
    print_status "Please start the main application first:"
    print_status "  ./deploy.sh"
    exit 1
fi

# Check RSS service
if ! docker ps | grep -q "viralogic-deploy_rss-service"; then
    print_error "RSS service container not running"
    print_status "Please start the RSS service first:"
    print_status "  docker-compose -f rss-service/docker-compose-rss.yml up -d"
    exit 1
fi

print_success "All required services are running"

# Function to check migration status
check_migration_status() {
    local service_name=$1
    local compose_file=$2
    local service_container=$3
    
    print_status "Checking $service_name migration status..."
    if docker-compose -f "$compose_file" exec -T "$service_container" python -m alembic current; then
        print_success "$service_name migration status checked"
    else
        print_warning "Could not check $service_name migration status"
    fi
}

# Function to run migrations
run_migrations() {
    local service_name=$1
    local compose_file=$2
    local service_container=$3
    
    print_status "Running $service_name migrations..."
    if docker-compose -f "$compose_file" exec -T "$service_container" python -m alembic upgrade head; then
        print_success "$service_name migrations completed successfully"
        return 0
    else
        print_error "Failed to run $service_name migrations"
        return 1
    fi
}

# =============================================================================
# MAIN APPLICATION MIGRATIONS
# =============================================================================
print_status "Starting main application migrations..."

# Check current migration status
check_migration_status "Main Application" "Viralogic/docker-compose-main.yml" "backend"

# Run migrations
if run_migrations "Main Application" "Viralogic/docker-compose-main.yml" "backend"; then
    print_success "✅ Main application migrations completed"
else
    print_error "❌ Main application migrations failed"
    print_status "Checking migration status for debugging..."
    docker-compose -f Viralogic/docker-compose-main.yml exec -T backend python -m alembic current
    exit 1
fi

# =============================================================================
# RSS SERVICE MIGRATIONS
# =============================================================================
print_status "Starting RSS service migrations..."

# Check current migration status
check_migration_status "RSS Service" "rss-service/docker-compose-rss.yml" "rss-service"

# Run migrations
if run_migrations "RSS Service" "rss-service/docker-compose-rss.yml" "rss-service"; then
    print_success "✅ RSS service migrations completed"
else
    print_error "❌ RSS service migrations failed"
    print_status "Checking migration status for debugging..."
    docker-compose -f rss-service/docker-compose-rss.yml exec -T rss-service python -m alembic current
    exit 1
fi

# =============================================================================
# FINAL STATUS CHECK
# =============================================================================
print_status "Final migration status check..."

print_status "Main application migration status:"
docker-compose -f Viralogic/docker-compose-main.yml exec -T backend python -m alembic current

print_status "RSS service migration status:"
docker-compose -f rss-service/docker-compose-rss.yml exec -T rss-service python -m alembic current

print_success "🎉 All database migrations completed successfully!"
echo ""
print_status "💡 Next steps:"
print_status "  - Your AI content generation queue should now work properly"
print_status "  - The new ai_task_id and queued_at fields are now available"
print_status "  - source_url field length has been extended to handle longer URLs"
echo ""
print_status "🔍 To verify everything is working:"
print_status "  - Check the 3 AM schedule logs for successful execution"
print_status "  - Monitor the AI content generation queue processing"
print_status "  - Verify social posts are moving from 'pending' to 'completed' status"
