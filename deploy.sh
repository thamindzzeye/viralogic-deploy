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
CONFIGS_DIR="$SCRIPT_DIR/configs"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Default values
ENVIRONMENT="production"
ACTION="deploy"
DOCKER_COMPOSE_FILE="$CONFIGS_DIR/docker-compose.production.yml"
RSS_COMPOSE_FILE="$CONFIGS_DIR/docker-compose.rss-service.yml"

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

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if environment file exists
    if [[ ! -f "$CONFIGS_DIR/.env.production" ]]; then
        print_error "Environment file not found: $CONFIGS_DIR/.env.production"
        print_status "Please copy env.production.example and configure it:"
        print_status "cp $CONFIGS_DIR/env.production.example $CONFIGS_DIR/.env.production"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to setup server
setup_server() {
    print_status "Setting up server..."
    
    OS=$(detect_os)
    print_status "Detected OS: $OS"
    
    if [[ "$OS" == "macos" ]]; then
        # macOS setup
        if ! command -v brew &> /dev/null; then
            print_status "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        if ! command -v docker &> /dev/null; then
            print_status "Installing Docker Desktop..."
            brew install --cask docker
        fi
        
        if ! command -v cloudflared &> /dev/null; then
            print_status "Installing Cloudflare Tunnel..."
            brew install cloudflare/cloudflare/cloudflared
        fi
        
    elif [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        # Ubuntu/Debian setup
        if ! command -v docker &> /dev/null; then
            print_status "Installing Docker..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            sudo usermod -aG docker $USER
        fi
        
        if ! command -v cloudflared &> /dev/null; then
            print_status "Installing Cloudflare Tunnel..."
            curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
            sudo dpkg -i cloudflared.deb
        fi
        
    else
        print_warning "Unsupported OS: $OS. Please install Docker and Cloudflare Tunnel manually."
    fi
    
    print_success "Server setup completed"
    
    # Setup environment file
    print_status "Setting up environment file..."
    if [[ -f "$SCRIPTS_DIR/setup-env.sh" ]]; then
        "$SCRIPTS_DIR/setup-env.sh"
    else
        print_warning "Environment setup script not found"
    fi
}

# Function to setup Cloudflare Tunnel
setup_cloudflare_tunnel() {
    print_status "Setting up Cloudflare Tunnel..."
    
    if [[ ! -f "$CONFIGS_DIR/cloudflare-tunnel.yml" ]]; then
        print_error "Cloudflare tunnel config not found: $CONFIGS_DIR/cloudflare-tunnel.yml"
        print_status "Please create the tunnel configuration file"
        exit 1
    fi
    
    # Check if tunnel is already running
    if pgrep -f "cloudflared tunnel" > /dev/null; then
        print_status "Cloudflare tunnel is already running"
    else
        print_status "Starting Cloudflare tunnel..."
        cloudflared tunnel --config "$CONFIGS_DIR/cloudflare-tunnel.yml" run &
        sleep 5
    fi
    
    print_success "Cloudflare tunnel setup completed"
}

# Function to deploy main application
deploy_main_app() {
    print_status "Deploying main Viralogic application..."
    
    # Pull latest images
    print_status "Pulling latest images..."
    docker-compose -f "$DOCKER_COMPOSE_FILE" pull
    
    # Deploy with environment file
    print_status "Starting services..."
    docker-compose -f "$DOCKER_COMPOSE_FILE" --env-file "$CONFIGS_DIR/.env.production" up -d
    
    # Wait for services to be healthy
    print_status "Waiting for services to be healthy..."
    sleep 30
    
    # Check service status
    docker-compose -f "$DOCKER_COMPOSE_FILE" ps
    
    print_success "Main application deployed successfully"
}

# Function to deploy RSS service
deploy_rss_service() {
    print_status "Deploying RSS service..."
    
    if [[ ! -f "$RSS_COMPOSE_FILE" ]]; then
        print_warning "RSS service compose file not found, skipping RSS deployment"
        return
    fi
    
    # Pull latest images
    print_status "Pulling latest RSS service images..."
    docker-compose -f "$RSS_COMPOSE_FILE" pull
    
    # Deploy RSS service
    print_status "Starting RSS services..."
    docker-compose -f "$RSS_COMPOSE_FILE" --env-file "$CONFIGS_DIR/.env.production" up -d
    
    # Wait for services to be healthy
    print_status "Waiting for RSS services to be healthy..."
    sleep 20
    
    # Check service status
    docker-compose -f "$RSS_COMPOSE_FILE" ps
    
    print_success "RSS service deployed successfully"
}

# Function to check status
check_status() {
    print_status "Checking service status..."
    
    echo ""
    echo "=== Main Application Status ==="
    docker-compose -f "$DOCKER_COMPOSE_FILE" ps
    
    if [[ -f "$RSS_COMPOSE_FILE" ]]; then
        echo ""
        echo "=== RSS Service Status ==="
        docker-compose -f "$RSS_COMPOSE_FILE" ps
    fi
    
    echo ""
    echo "=== System Resources ==="
    docker system df
}

# Function to show logs
show_logs() {
    local service=${1:-""}
    
    if [[ -n "$service" ]]; then
        print_status "Showing logs for service: $service"
        docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f "$service"
    else
        print_status "Showing all logs (Ctrl+C to exit)"
        docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f
    fi
}

# Function to update application
update_application() {
    print_status "Updating application..."
    
    # Stop services
    print_status "Stopping services..."
    docker-compose -f "$DOCKER_COMPOSE_FILE" down
    
    # Pull latest images
    print_status "Pulling latest images..."
    docker-compose -f "$DOCKER_COMPOSE_FILE" pull
    
    # Start services
    print_status "Starting services..."
    docker-compose -f "$DOCKER_COMPOSE_FILE" --env-file "$CONFIGS_DIR/.env.production" up -d
    
    # Wait for services to be healthy
    print_status "Waiting for services to be healthy..."
    sleep 30
    
    print_success "Application updated successfully"
}

# Function to stop services
stop_services() {
    print_status "Stopping services..."
    
    docker-compose -f "$DOCKER_COMPOSE_FILE" down
    
    if [[ -f "$RSS_COMPOSE_FILE" ]]; then
        docker-compose -f "$RSS_COMPOSE_FILE" down
    fi
    
    print_success "Services stopped"
}

# Function to restart services
restart_services() {
    print_status "Restarting services..."
    
    docker-compose -f "$DOCKER_COMPOSE_FILE" restart
    
    if [[ -f "$RSS_COMPOSE_FILE" ]]; then
        docker-compose -f "$RSS_COMPOSE_FILE" restart
    fi
    
    print_success "Services restarted"
}

# Function to backup database
backup_database() {
    print_status "Creating database backup..."
    
    local backup_dir="$SCRIPT_DIR/backups"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$backup_dir/backup_$timestamp.sql"
    
    mkdir -p "$backup_dir"
    
    # Source environment variables
    source "$CONFIGS_DIR/.env.production"
    
    # Create backup
    docker-compose -f "$DOCKER_COMPOSE_FILE" exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$backup_file"
    
    print_success "Database backup created: $backup_file"
}

# Function to monitor health
monitor_health() {
    print_status "Starting health monitoring..."
    
    # Run monitoring script if it exists
    if [[ -f "$SCRIPTS_DIR/monitor.sh" ]]; then
        "$SCRIPTS_DIR/monitor.sh"
    else
        print_warning "Monitor script not found, showing basic status"
        check_status
    fi
}

# Function to show usage
show_usage() {
    echo "Viralogic Deployment Script"
    echo ""
    echo "Usage: $0 [environment] [action] [options]"
    echo ""
    echo "Environments:"
    echo "  production    Deploy to production environment"
    echo ""
    echo "Actions:"
    echo "  deploy        Deploy the application"
    echo "  status        Check service status"
    echo "  logs [service] Show logs (all or specific service)"
    echo "  update        Update to latest version"
    echo "  stop          Stop all services"
    echo "  restart       Restart all services"
    echo "  backup        Create database backup"
    echo "  monitor       Monitor application health"
    echo "  setup         Setup server (install dependencies)"
    echo ""
    echo "Examples:"
    echo "  $0 production deploy"
    echo "  $0 production status"
    echo "  $0 production logs backend"
    echo "  $0 production update"
}

# Main script logic
main() {
    # Parse arguments
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi
    
    ENVIRONMENT="$1"
    ACTION="$2"
    SERVICE="$3"
    
    # Validate environment
    if [[ "$ENVIRONMENT" != "production" ]]; then
        print_error "Invalid environment: $ENVIRONMENT"
        print_status "Supported environments: production"
        exit 1
    fi
    
    # Check prerequisites for most actions
    if [[ "$ACTION" != "setup" ]]; then
        check_prerequisites
    fi
    
    # Execute action
    case "$ACTION" in
        "deploy")
            setup_cloudflare_tunnel
            deploy_main_app
            deploy_rss_service
            check_status
            ;;
        "status")
            check_status
            ;;
        "logs")
            show_logs "$SERVICE"
            ;;
        "update")
            update_application
            check_status
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            restart_services
            check_status
            ;;
        "backup")
            backup_database
            ;;
        "monitor")
            monitor_health
            ;;
        "setup")
            setup_server
            ;;
        *)
            print_error "Invalid action: $ACTION"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
