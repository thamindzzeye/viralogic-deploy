#!/bin/bash

# Viralogic Database Migration Script
# Dumps dev databases and restores to production

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

# Check if this is a dump or restore operation
OPERATION=${1:-dump}
BACKUP_DIR=${2:-./backups}

print_status "Starting Viralogic database migration..."
print_status "Operation: $OPERATION"
print_status "Backup directory: $BACKUP_DIR"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to dump main app database
dump_main_db() {
    print_status "Dumping main application database..."
    
    # Get database credentials from dev environment
    source backend/.env 2>/dev/null || {
        print_error "Could not load backend/.env file"
        print_status "Please ensure backend/.env exists with database credentials"
        exit 1
    }
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local dump_file="$BACKUP_DIR/viralogic_main_${timestamp}.sql"
    
    # Dump the database
    if pg_dump -h localhost -p 5432 -U viralogic_user -d viralogic > "$dump_file"; then
        print_success "Main database dumped to: $dump_file"
        echo "$dump_file" > "$BACKUP_DIR/latest_main_dump.txt"
    else
        print_error "Failed to dump main database"
        exit 1
    fi
}

# Function to dump RSS database
dump_rss_db() {
    print_status "Dumping RSS service database..."
    
    # Get database credentials from RSS service environment
    source micro-services/rss-service/.env 2>/dev/null || {
        print_error "Could not load micro-services/rss-service/.env file"
        print_status "Please ensure RSS service .env exists with database credentials"
        exit 1
    }
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local dump_file="$BACKUP_DIR/viralogic_rss_${timestamp}.sql"
    
    # Dump the RSS database
    if pg_dump -h localhost -p 5432 -U viralogic_rss_user -d viralogic_rss > "$dump_file"; then
        print_success "RSS database dumped to: $dump_file"
        echo "$dump_file" > "$BACKUP_DIR/latest_rss_dump.txt"
    else
        print_error "Failed to dump RSS database"
        exit 1
    fi
}

# Function to restore main app database
restore_main_db() {
    print_status "Restoring main application database..."
    
    # Get the latest dump file
    local dump_file
    if [[ -f "$BACKUP_DIR/latest_main_dump.txt" ]]; then
        dump_file=$(cat "$BACKUP_DIR/latest_main_dump.txt")
    else
        print_error "No main database dump found. Run 'dump' first."
        exit 1
    fi
    
    if [[ ! -f "$dump_file" ]]; then
        print_error "Dump file not found: $dump_file"
        exit 1
    fi
    
    print_status "Using dump file: $dump_file"
    
    # Load production environment variables
    source .env 2>/dev/null || {
        print_error "Could not load production .env file"
        exit 1
    }
    
    # Stop the main application to avoid conflicts
    print_status "Stopping main application services..."
    docker-compose -f docker-compose-main.yml down
    
    # Wait a moment for services to stop
    sleep 5
    
    # Restore the database
    print_status "Restoring main database..."
    if PGPASSWORD="$DB_PASSWORD" psql -h localhost -p 1723 -U viralogic_user -d viralogic < "$dump_file"; then
        print_success "Main database restored successfully"
    else
        print_error "Failed to restore main database"
        exit 1
    fi
    
    # Restart the main application
    print_status "Restarting main application services..."
    docker-compose -f docker-compose-main.yml up -d
}

# Function to restore RSS database
restore_rss_db() {
    print_status "Restoring RSS service database..."
    
    # Get the latest dump file
    local dump_file
    if [[ -f "$BACKUP_DIR/latest_rss_dump.txt" ]]; then
        dump_file=$(cat "$BACKUP_DIR/latest_rss_dump.txt")
    else
        print_error "No RSS database dump found. Run 'dump' first."
        exit 1
    fi
    
    if [[ ! -f "$dump_file" ]]; then
        print_error "Dump file not found: $dump_file"
        exit 1
    fi
    
    print_status "Using dump file: $dump_file"
    
    # Load production environment variables
    source .env 2>/dev/null || {
        print_error "Could not load production .env file"
        exit 1
    }
    
    # Stop the RSS service to avoid conflicts
    print_status "Stopping RSS service..."
    docker-compose -f docker-compose-rss.yml down
    
    # Wait a moment for services to stop
    sleep 5
    
    # Restore the database
    print_status "Restoring RSS database..."
    if PGPASSWORD="$RSS_DB_PASSWORD" psql -h localhost -p 1725 -U viralogic_rss_user -d viralogic_rss < "$dump_file"; then
        print_success "RSS database restored successfully"
    else
        print_error "Failed to restore RSS database"
        exit 1
    fi
    
    # Restart the RSS service
    print_status "Restarting RSS service..."
    docker-compose -f docker-compose-rss.yml up -d
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
        print_status "Starting database dump operation..."
        dump_main_db
        dump_rss_db
        print_success "Database dump completed successfully!"
        print_status "Dumps saved to: $BACKUP_DIR"
        ;;
    "restore")
        print_status "Starting database restore operation..."
        restore_main_db
        restore_rss_db
        print_success "Database restore completed successfully!"
        ;;
    "dump-main")
        dump_main_db
        ;;
    "dump-rss")
        dump_rss_db
        ;;
    "restore-main")
        restore_main_db
        ;;
    "restore-rss")
        restore_rss_db
        ;;
    "list")
        list_dumps
        ;;
    *)
        echo "Usage: $0 [operation] [backup-dir]"
        echo ""
        echo "Operations:"
        echo "  dump          - Dump both main and RSS databases"
        echo "  restore       - Restore both main and RSS databases"
        echo "  dump-main     - Dump only main application database"
        echo "  dump-rss      - Dump only RSS service database"
        echo "  restore-main  - Restore only main application database"
        echo "  restore-rss   - Restore only RSS service database"
        echo "  list          - List available database dumps"
        echo ""
        echo "Examples:"
        echo "  $0 dump                    # Dump both databases"
        echo "  $0 restore                 # Restore both databases"
        echo "  $0 dump ./my-backups       # Dump to custom directory"
        echo "  $0 list                    # List available dumps"
        exit 1
        ;;
esac
