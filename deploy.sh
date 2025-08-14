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
        
        fi
        
    elif [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        # Ubuntu/Debian setup
        if ! command -v docker &> /dev/null; then
            print_status "Installing Docker..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            sudo usermod -aG docker $USER
        fi
        
