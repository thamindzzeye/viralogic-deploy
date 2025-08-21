#!/bin/bash

# RSS Database Restore Script
# Copies PostgreSQL data directory from backup

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

print_status "🚀 RSS Database Restore Script"
print_status "This script copies PostgreSQL data directory from backup"

# Check if backup directory is provided
BACKUP_DIR=${1:-"../backup-databases/rss-postgres"}
print_status "Backup directory: $BACKUP_DIR"

if [[ ! -d "$BACKUP_DIR" ]]; then
    print_error "Backup directory not found: $BACKUP_DIR"
    print_status "Usage: $0 [backup-directory]"
    print_status "Example: $0 /path/to/backup/rss-postgres"
    exit 1
fi

# Stop the RSS postgres container
print_status "Stopping RSS postgres container..."
docker-compose -f rss-service/docker-compose-rss-local.yml stop rss-postgres

# Wait for container to stop
sleep 5

# Remove the existing data directory
print_status "Removing existing data directory..."
sudo rm -rf ../../docker_volumes/rss-service/postgres/*

# Copy the backup data
print_status "Copying backup data..."
sudo cp -r "$BACKUP_DIR"/* ../../docker_volumes/rss-service/postgres/

# Fix permissions
print_status "Fixing permissions..."
sudo chown -R 999:999 ../../docker_volumes/rss-service/postgres/

# Start the postgres container
print_status "Starting RSS postgres container..."
docker-compose -f rss-service/docker-compose-rss-local.yml up -d rss-postgres

# Wait for postgres to start
print_status "Waiting for postgres to start..."
sleep 10

# Test the connection
print_status "Testing database connection..."
if docker exec rss-service-rss-postgres-1 pg_isready -U ricky -d rss_service; then
    print_success "RSS database restored successfully!"
else
    print_error "Database connection test failed"
    exit 1
fi

print_success "🎉 RSS database restore completed!"
print_status "You can now start the rest of the services:"
print_status "docker-compose -f rss-service/docker-compose-rss-local.yml up -d"
