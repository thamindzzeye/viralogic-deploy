# Viralogic Production Deployment

This repository contains the production deployment configuration for the Viralogic platform.

## Quick Deploy

```bash
# Deploy with latest images
./deploy.sh

# Deploy with specific image tag
./deploy.sh main
```

## Prerequisites

1. **Docker & Docker Compose** installed on your server
2. **Cloudflare Tunnel credentials** in JSON format
3. **GitHub Container Registry access** (images are built by GitHub Actions)

## Setup

### 1. Create Cloudflare Tunnels

Create two tunnels in your Cloudflare Zero Trust Dashboard:
- `viralogic-production` - for main application
- `viralogic-rss-production` - for RSS service

Download the JSON credentials for each tunnel.

### 2. Add Tunnel Credentials

Create the tunnel JSON files in the `cloudflared/` directory:

```bash
# Main app tunnel
echo 'YOUR_MAIN_TUNNEL_JSON_CONTENT' > cloudflared/viralogic-production-tunnel.json

# RSS service tunnel  
echo 'YOUR_RSS_TUNNEL_JSON_CONTENT' > cloudflared/viralogic-rss-production-tunnel.json
```

### 3. Verify Files

Ensure you have these files:
- `docker-compose-main.yml` - Main application services
- `docker-compose-rss.yml` - RSS service
- `cloudflared/config.yml` - Main tunnel configuration
- `cloudflared/rss-config.yml` - RSS tunnel configuration
- `cloudflared/viralogic-production-tunnel.json` - Main tunnel credentials
- `cloudflared/viralogic-rss-production-tunnel.json` - RSS tunnel credentials

## Deployment Process

The deployment script will:

1. ✅ Check prerequisites (Docker, required files)
2. ✅ Pull latest Docker images from GitHub Container Registry
3. ✅ Deploy main application (`docker-compose-main.yml`)
4. ✅ Deploy RSS service (`docker-compose-rss.yml`)
5. ✅ Run health checks
6. ✅ Display service status

## Services

### Main Application (Port 1720-1721)
- **Backend**: `ghcr.io/thamindzzeye/viralogic/backend:main`
- **Frontend**: `ghcr.io/thamindzzeye/viralogic/frontend:main`
- **PostgreSQL**: Port 1723
- **Redis**: Port 1724
- **Celery Worker & Beat**: Background tasks

### RSS Service (Port 1722)
- **RSS Service**: `ghcr.io/thamindzzeye/viralogic/rss-service:main`

### Cloudflare Tunnels
- **Main App**: `viralogic-production` → `viralogic.tbdv.org` & `viralogic-api.tbdv.org`
- **RSS Service**: `viralogic-rss-production` → `rss.viralogic.io`

## Monitoring

```bash
# View logs
docker-compose -f docker-compose-main.yml logs -f
docker-compose -f docker-compose-rss.yml logs -f

# Check status
docker-compose -f docker-compose-main.yml ps
docker-compose -f docker-compose-rss.yml ps

# Health checks
curl http://localhost:1720/health  # Backend
curl http://localhost:1721         # Frontend
curl http://localhost:1722/health/public  # RSS Service
```

## Troubleshooting

### Missing Tunnel Credentials
```bash
# Check if tunnel files exist
ls -la cloudflared/*.json

# Create from GitHub secrets (if you have access)
echo '$GITHUB_SECRET_CONTENT' > cloudflared/viralogic-production-tunnel.json
```

### Image Pull Issues
```bash
# Check if you can access GitHub Container Registry
docker pull ghcr.io/thamindzzeye/viralogic/backend:main

# Verify image exists
docker images | grep viralogic
```

### Port Conflicts
All services use standardized ports:
- Backend: 1720
- Frontend: 1721  
- RSS Service: 1722
- PostgreSQL: 1723
- Redis: 1724

## Build Process

Images are built automatically by GitHub Actions when you push to the `main` branch:
1. Code is built into Docker images
2. Images are pushed to `ghcr.io/thamindzzeye/viralogic/`
3. You manually deploy using this script

## Security

- All environment variables are baked into Docker images during build
- No `.env` files needed on production server
- Cloudflare tunnels provide secure external access
- All secrets managed via GitHub Secrets
- **Cloudflare tunnel JSON files are excluded from git** (see `.gitignore`)
- **Never commit sensitive credentials to version control**
