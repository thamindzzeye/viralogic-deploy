#!/bin/bash

# Cloudflare Tunnel Setup Script for Docker Deployment
# Helps you set up tunnel credentials for containerized deployment

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

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$SCRIPT_DIR/../configs"

print_status "Setting up Cloudflare Tunnel for Docker deployment..."

# Check if credentials file exists
if [[ -f "$CONFIGS_DIR/tunnel-credentials.json" ]]; then
    print_success "Tunnel credentials already exist: $CONFIGS_DIR/tunnel-credentials.json"
else
    print_warning "Tunnel credentials not found!"
    print_status ""
    print_status "To set up Cloudflare Tunnel:"
    print_status ""
    print_status "1. Go to Cloudflare Zero Trust Dashboard:"
    print_status "   https://dash.cloudflare.com/"
    print_status ""
    print_status "2. Navigate to Access → Tunnels"
    print_status ""
    print_status "3. Create a new tunnel or use existing one"
    print_status ""
    print_status "4. Download the credentials JSON file"
    print_status ""
    print_status "5. Save it as: $CONFIGS_DIR/tunnel-credentials.json"
    print_status ""
    print_status "6. Update tunnel ID in: $CONFIGS_DIR/cloudflare-tunnel.yml"
    print_status ""
    print_error "Please download your tunnel credentials and try again"
    exit 1
fi

# Check if tunnel config exists
if [[ ! -f "$CONFIGS_DIR/cloudflare-tunnel.yml" ]]; then
    print_error "Tunnel config not found: $CONFIGS_DIR/cloudflare-tunnel.yml"
    exit 1
fi

# Verify tunnel ID is set
TUNNEL_ID=$(grep "tunnel:" "$CONFIGS_DIR/cloudflare-tunnel.yml" | cut -d' ' -f2)
if [[ "$TUNNEL_ID" == "your-tunnel-id-here" ]]; then
    print_warning "Tunnel ID not configured!"
    print_status "Please update the tunnel ID in: $CONFIGS_DIR/cloudflare-tunnel.yml"
    print_status "Replace 'your-tunnel-id-here' with your actual tunnel ID"
    exit 1
fi

print_success "Cloudflare tunnel setup complete!"
print_status ""
print_status "Tunnel ID: $TUNNEL_ID"
print_status "Credentials: $CONFIGS_DIR/tunnel-credentials.json"
print_status "Config: $CONFIGS_DIR/cloudflare-tunnel.yml"
print_status ""
print_status "The tunnel will be managed by Docker Compose during deployment"
print_status ""
print_status "To test the tunnel manually:"
print_status "  docker run --rm -v $CONFIGS_DIR/cloudflare-tunnel.yml:/etc/cloudflared/config.yml:ro \\"
print_status "    -v $CONFIGS_DIR/tunnel-credentials.json:/etc/cloudflared/tunnel-credentials.json:ro \\"
print_status "    --network host cloudflare/cloudflared:latest \\"
print_status "    tunnel --config /etc/cloudflared/config.yml run"
