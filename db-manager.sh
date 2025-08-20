#!/bin/bash

# Viralogic Database Management Script
# Handles both dump (from dev) and restore (to production)
# Run this from your viralogic-deploy directory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check operation
OPERATION=${1:-dump}
BACKUP_DIR=${2:-./backups}

print_status "🚀 Viralogic Database Management Script"
print_status "Operation: $OPERATION"
print_status "Backup directory: $BACKUP_DIR"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to dump databases from production environment
dump_databases() {
    print_status "Starting database dump from production environment..."
    
    # Get current timestamp
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    print_status "Timestamp: $TIMESTAMP"
    
    # Check if production services are running
    print_status "Checking if production services are running..."
    
    if ! docker ps | grep -q "viralogic-deploy_postgres"; then
        print_error "Production PostgreSQL container not running. Please start production environment first:"
        print_status "   ./deploy.sh"
        exit 1
    fi
    
    if ! docker ps | grep -q "viralogic-deploy_rss-postgres"; then
        print_error "Production RSS PostgreSQL container not running. Please start RSS service first:"
        print_status "   docker-compose -f docker-compose-rss.yml up -d"
        exit 1
    fi
    
    print_success "Production services are running"
    
    # Load environment variables
    print_status "Loading environment variables..."
    
    if [[ -f ".env" ]]; then
        source .env
        print_success "Loaded production environment"
    else
        print_error ".env not found"
        exit 1
    fi
    
    # Dump main database
    print_status "Dumping main application database..."
    MAIN_DUMP="$BACKUP_DIR/viralogic_main_${TIMESTAMP}.sql"
    
    if PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h localhost -p 1723 -U "$POSTGRES_USER" -d "$POSTGRES_DB" > "$MAIN_DUMP"; then
        print_success "Main database dumped to: $MAIN_DUMP"
        echo "$MAIN_DUMP" > "$BACKUP_DIR/latest_main_dump.txt"
    else
        print_error "Failed to dump main database"
        exit 1
    fi
    
    # Dump RSS database
    print_status "Dumping RSS service database..."
    RSS_DUMP="$BACKUP_DIR/viralogic_rss_${TIMESTAMP}.sql"
    
    if PGPASSWORD="$RSS_DB_PASSWORD" pg_dump -h localhost -p 1725 -U "$RSS_DB_USER" -d "$RSS_DB_NAME" > "$RSS_DUMP"; then
        print_success "RSS database dumped to: $RSS_DUMP"
        echo "$RSS_DUMP" > "$BACKUP_DIR/latest_rss_dump.txt"
    else
        print_error "Failed to dump RSS database"
        exit 1
    fi
    
    print_success "Database dump completed successfully!"
    print_status "Dump files created:"
    print_status "   Main DB: $MAIN_DUMP"
    print_status "   RSS DB:  $RSS_DUMP"
    print_status "Dump file sizes:"
    ls -lh "$MAIN_DUMP" "$RSS_DUMP"
}

# Function to restore databases to production
restore_databases() {
    print_status "Starting database restore to production..."
    
    # Get the latest dump files
    local main_dump
    local rss_dump
    
    if [[ -f "$BACKUP_DIR/latest_main_dump.txt" ]]; then
        main_dump=$(cat "$BACKUP_DIR/latest_main_dump.txt")
    else
        print_error "No main database dump found. Run 'dump' first."
        exit 1
    fi
    
    if [[ -f "$BACKUP_DIR/latest_rss_dump.txt" ]]; then
        rss_dump=$(cat "$BACKUP_DIR/latest_rss_dump.txt")
    else
        print_error "No RSS database dump found. Run 'dump' first."
        exit 1
    fi
    
    if [[ ! -f "$main_dump" ]] || [[ ! -f "$rss_dump" ]]; then
        print_error "Dump files not found. Please ensure dumps exist in $BACKUP_DIR"
        exit 1
    fi
    
    print_status "Using dump files:"
    print_status "   Main: $main_dump"
    print_status "   RSS:  $rss_dump"
    
    # Load production environment variables
    if [[ -f ".env" ]]; then
        source .env
        print_success "Loaded production environment"
    else
        print_error "Production .env file not found"
        exit 1
    fi
    
    # Stop services to avoid conflicts
    print_status "Stopping production services..."
    docker-compose -f docker-compose-main.yml down
    docker-compose -f docker-compose-rss.yml down
    
    # Wait for services to stop
    sleep 5
    
    # Restore main database
    print_status "Restoring main database..."
    if PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -p 1723 -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$main_dump"; then
        print_success "Main database restored successfully"
    else
        print_error "Failed to restore main database"
        exit 1
    fi
    
    # Restore RSS database
    print_status "Restoring RSS database..."
    if PGPASSWORD="$RSS_DB_PASSWORD" psql -h localhost -p 1725 -U "$RSS_DB_USER" -d "$RSS_DB_NAME" < "$rss_dump"; then
        print_success "RSS database restored successfully"
    else
        print_error "Failed to restore RSS database"
        exit 1
    fi
    
    # Restart services
    print_status "Restarting production services..."
    docker-compose -f docker-compose-main.yml up -d
    docker-compose -f docker-compose-rss.yml up -d
    
    print_success "Database restore completed successfully!"
}

# Function to list available dumps
list_dumps() {
    print_status "Available database dumps:"
    echo ""
    
    if [[ -f "$BACKUP_DIR/latest_main_dump.txt" ]]; then
        local main_dump=$(cat "$BACKUP_DIR/latest_main_dump.txt")
        print_status "Latest main database dump: $main_dump"
    else
        print_warning "No main database dumps found"
    fi
    
    if [[ -f "$BACKUP_DIR/latest_rss_dump.txt" ]]; then
        local rss_dump=$(cat "$BACKUP_DIR/latest_rss_dump.txt")
        print_status "Latest RSS database dump: $rss_dump"
    else
        print_warning "No RSS database dumps found"
    fi
    
    echo ""
    print_status "All dump files in $BACKUP_DIR:"
    ls -la "$BACKUP_DIR"/*.sql 2>/dev/null || print_warning "No .sql files found"
}

# Main execution
case "$OPERATION" in
    "dump")
        dump_databases
        print_status "Next steps:"
        print_status "   1. Copy backup files to your production server"
        print_status "   2. Run restore on production: ./db-manager.sh restore"
        ;;
    "restore")
        restore_databases
        ;;
    "list")
        list_dumps
        ;;
    *)
        echo "Usage: $0 [operation] [backup-dir]"
        echo ""
        echo "Operations:"
        echo "  dump          - Dump both databases from dev environment"
        echo "  restore       - Restore both databases to production"
        echo "  list          - List available database dumps"
        echo ""
        echo "Examples:"
        echo "  $0 dump                    # Dump from dev"
        echo "  $0 restore                 # Restore to production"
        echo "  $0 dump ./my-backups       # Dump to custom directory"
        echo "  $0 list                    # List available dumps"
        echo ""
        echo "Note: This script works in both dev and production environments"
        exit 1
        ;;
esac
