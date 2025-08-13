#!/bin/bash

# Viralogic Backup Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$SCRIPT_DIR/../configs"

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

# Create backup directory
create_backup_dir() {
    local backup_dir="$SCRIPT_DIR/../backups"
    mkdir -p "$backup_dir"
    echo "$backup_dir"
}

# Backup main application database
backup_main_db() {
    print_status "Backing up main application database..."
    
    local backup_dir=$(create_backup_dir)
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$backup_dir/main_db_backup_$timestamp.sql"
    
    # Source environment variables
    if [[ -f "$CONFIGS_DIR/.env.production" ]]; then
        source "$CONFIGS_DIR/.env.production"
    fi
    
    # Create backup
    docker-compose -f "$CONFIGS_DIR/docker-compose.production.yml" exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$backup_file"
    
    print_success "Main database backup created: $backup_file"
    echo "$backup_file"
}

# Backup RSS service database
backup_rss_db() {
    print_status "Backing up RSS service database..."
    
    local backup_dir=$(create_backup_dir)
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$backup_dir/rss_db_backup_$timestamp.sql"
    
    # Source environment variables
    if [[ -f "$CONFIGS_DIR/.env.production" ]]; then
        source "$CONFIGS_DIR/.env.production"
    fi
    
    # Create backup
    docker-compose -f "$CONFIGS_DIR/docker-compose.rss-service.yml" exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$backup_file"
    
    print_success "RSS database backup created: $backup_file"
    echo "$backup_file"
}

# Backup configuration files
backup_configs() {
    print_status "Backing up configuration files..."
    
    local backup_dir=$(create_backup_dir)
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local config_backup_dir="$backup_dir/configs_$timestamp"
    
    mkdir -p "$config_backup_dir"
    
    # Copy configuration files
    cp -r "$CONFIGS_DIR"/* "$config_backup_dir/"
    
    print_success "Configuration backup created: $config_backup_dir"
    echo "$config_backup_dir"
}

# Backup logs
backup_logs() {
    print_status "Backing up application logs..."
    
    local backup_dir=$(create_backup_dir)
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local logs_backup_dir="$backup_dir/logs_$timestamp"
    
    mkdir -p "$logs_backup_dir"
    
    # Copy logs if they exist
    if [[ -d "/logs" ]]; then
        cp -r /logs/* "$logs_backup_dir/" 2>/dev/null || true
    fi
    
    # Copy Docker logs
    docker-compose -f "$CONFIGS_DIR/docker-compose.production.yml" logs > "$logs_backup_dir/main_app.log" 2>/dev/null || true
    
    if [[ -f "$CONFIGS_DIR/docker-compose.rss-service.yml" ]]; then
        docker-compose -f "$CONFIGS_DIR/docker-compose.rss-service.yml" logs > "$logs_backup_dir/rss_service.log" 2>/dev/null || true
    fi
    
    print_success "Logs backup created: $logs_backup_dir"
    echo "$logs_backup_dir"
}

# Create compressed archive
create_archive() {
    local backup_dir=$(create_backup_dir)
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local archive_name="viralogic_backup_$timestamp.tar.gz"
    local archive_path="$backup_dir/$archive_name"
    
    print_status "Creating compressed archive..."
    
    cd "$backup_dir"
    tar -czf "$archive_name" . --exclude="*.tar.gz" 2>/dev/null || true
    
    print_success "Backup archive created: $archive_path"
    echo "$archive_path"
}

# Clean old backups (keep last 7 days)
cleanup_old_backups() {
    print_status "Cleaning up old backups (older than 7 days)..."
    
    local backup_dir=$(create_backup_dir)
    local deleted_count=0
    
    # Find and delete backups older than 7 days
    find "$backup_dir" -name "*.sql" -mtime +7 -delete 2>/dev/null || true
    find "$backup_dir" -name "configs_*" -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
    find "$backup_dir" -name "logs_*" -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
    find "$backup_dir" -name "viralogic_backup_*.tar.gz" -mtime +7 -delete 2>/dev/null || true
    
    print_success "Old backups cleaned up"
}

# Main backup function
main() {
    echo "💾 Viralogic Backup System"
    echo "========================="
    
    local main_db_backup=""
    local rss_db_backup=""
    local config_backup=""
    local logs_backup=""
    local archive_path=""
    
    # Backup databases
    if [[ -f "$CONFIGS_DIR/docker-compose.production.yml" ]]; then
        main_db_backup=$(backup_main_db)
    fi
    
    if [[ -f "$CONFIGS_DIR/docker-compose.rss-service.yml" ]]; then
        rss_db_backup=$(backup_rss_db)
    fi
    
    # Backup configurations
    config_backup=$(backup_configs)
    
    # Backup logs
    logs_backup=$(backup_logs)
    
    # Create archive
    archive_path=$(create_archive)
    
    # Cleanup old backups
    cleanup_old_backups
    
    echo ""
    echo "📋 Backup Summary:"
    echo "=================="
    if [[ -n "$main_db_backup" ]]; then
        echo "✅ Main DB: $main_db_backup"
    fi
    if [[ -n "$rss_db_backup" ]]; then
        echo "✅ RSS DB: $rss_db_backup"
    fi
    echo "✅ Configs: $config_backup"
    echo "✅ Logs: $logs_backup"
    echo "✅ Archive: $archive_path"
    
    echo ""
    print_success "Backup completed successfully!"
}

# Run main function
main "$@"
