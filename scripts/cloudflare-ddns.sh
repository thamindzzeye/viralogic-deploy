#!/bin/bash

# Cloudflare Dynamic DNS Script
# Updates DNS records when IP address changes

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

# Configuration
ZONE_NAME="tbdv.org"  # Your domain
RECORD_NAME="macstudio"  # Subdomain (will create macstudio.tbdv.org)
TTL=300  # Time to live in seconds

# Get current public IP
get_current_ip() {
    curl -s ifconfig.me
}

# Get Cloudflare Zone ID
get_zone_id() {
    local zone_name=$1
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" | \
        jq -r '.result[0].id'
}

# Get DNS record ID
get_record_id() {
    local zone_id=$1
    local record_name=$2
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$record_name.$ZONE_NAME" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" | \
        jq -r '.result[0].id'
}

# Update DNS record
update_dns_record() {
    local zone_id=$1
    local record_id=$2
    local ip_address=$3
    
    local response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"type\": \"A\",
            \"name\": \"$RECORD_NAME\",
            \"content\": \"$ip_address\",
            \"ttl\": $TTL,
            \"proxied\": false
        }")
    
    local success=$(echo "$response" | jq -r '.success')
    if [[ "$success" == "true" ]]; then
        print_success "DNS record updated successfully"
        return 0
    else
        local error=$(echo "$response" | jq -r '.errors[0].message')
        print_error "Failed to update DNS record: $error"
        return 1
    fi
}

# Create DNS record if it doesn't exist
create_dns_record() {
    local zone_id=$1
    local ip_address=$2
    
    local response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"type\": \"A\",
            \"name\": \"$RECORD_NAME\",
            \"content\": \"$ip_address\",
            \"ttl\": $TTL,
            \"proxied\": false
        }")
    
    local success=$(echo "$response" | jq -r '.success')
    if [[ "$success" == "true" ]]; then
        print_success "DNS record created successfully"
        return 0
    else
        local error=$(echo "$response" | jq -r '.errors[0].message')
        print_error "Failed to create DNS record: $error"
        return 1
    fi
}

# Main function
main() {
    print_status "Starting Cloudflare Dynamic DNS update..."
    
    # Check if API token is set
    if [[ -z "$CLOUDFLARE_API_TOKEN" ]]; then
        print_error "CLOUDFLARE_API_TOKEN environment variable is not set"
        print_status "Set it with: export CLOUDFLARE_API_TOKEN='your-token-here'"
        exit 1
    fi
    
    # Get current IP
    print_status "Getting current public IP..."
    local current_ip=$(get_current_ip)
    print_status "Current IP: $current_ip"
    
    # Get zone ID
    print_status "Getting Cloudflare zone ID for $ZONE_NAME..."
    local zone_id=$(get_zone_id "$ZONE_NAME")
    if [[ "$zone_id" == "null" ]]; then
        print_error "Zone not found: $ZONE_NAME"
        exit 1
    fi
    print_status "Zone ID: $zone_id"
    
    # Check if record exists
    print_status "Checking if DNS record exists..."
    local record_id=$(get_record_id "$zone_id" "$RECORD_NAME")
    
    if [[ "$record_id" == "null" ]]; then
        print_status "DNS record doesn't exist, creating new record..."
        create_dns_record "$zone_id" "$current_ip"
    else
        print_status "DNS record exists, updating..."
        update_dns_record "$zone_id" "$record_id" "$current_ip"
    fi
    
    print_success "Dynamic DNS update completed!"
    print_status "Your Mac Studio is now accessible at: $RECORD_NAME.$ZONE_NAME"
}

# Show usage
show_usage() {
    echo "Cloudflare Dynamic DNS Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -z, --zone     Zone name (default: tbdv.org)"
    echo "  -r, --record   Record name (default: macstudio)"
    echo "  -t, --ttl      TTL in seconds (default: 300)"
    echo ""
    echo "Environment Variables:"
    echo "  CLOUDFLARE_API_TOKEN  Your Cloudflare API token"
    echo ""
    echo "Examples:"
    echo "  export CLOUDFLARE_API_TOKEN='your-token-here'"
    echo "  $0"
    echo "  $0 --zone yourdomain.com --record server"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -z|--zone)
            ZONE_NAME="$2"
            shift 2
            ;;
        -r|--record)
            RECORD_NAME="$2"
            shift 2
            ;;
        -t|--ttl)
            TTL="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Run main function
main "$@"
