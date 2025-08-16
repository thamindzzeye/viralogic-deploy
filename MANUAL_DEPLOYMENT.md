# Manual Deployment Guide

This guide explains how to manually deploy Viralogic to production using the `deploy-manual.sh` script.

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose installed on your server
- Access to GitHub Container Registry
- Environment file configured (`configs/.env.production`)

### Deploy Latest Version
```bash
# Deploy the latest images
./deploy-manual.sh

# Or specify a specific image tag
./deploy-manual.sh main-abc123
```

## 📋 What the Script Does

1. **Checks Prerequisites**
   - Verifies Docker and Docker Compose are installed
   - Ensures environment file exists

2. **Pulls Latest Code**
   - Updates the deployment repository
   - Pulls latest Docker images from GitHub Container Registry

3. **Deploys Services**
   - Stops existing containers
   - Starts new containers with latest images
   - Deploys both main app and RSS service

4. **Health Checks**
   - Verifies all services are running
   - Shows service status

## 🔧 Configuration

### Environment Variables
The script uses these environment variables:
- `GITHUB_REPOSITORY`: GitHub repository (default: `thamindzzeye/Viralogic`)
- `IMAGE_TAG`: Docker image tag (default: `latest`)

### Customization
You can override defaults:
```bash
export GITHUB_REPOSITORY=your-username/viralogic
export IMAGE_TAG=production-v1.0.0
./deploy-manual.sh
```

## 🏗️ Deployment Architecture

```
GitHub Actions → Build Images → Push to Registry
     ↓
Manual Deploy → Pull Images → Deploy with Docker Compose
     ↓
Cloudflare Tunnel → Route Traffic to Services
```

## 📊 Services Deployed

- **Frontend**: `https://viralogic.io` (port 3000)
- **Backend API**: `https://api.viralogic.io` (port 8000)
- **RSS Service**: `https://rss.viralogic.io` (port 8001)
- **File Storage**: `https://files.viralogic.io` (port 9000)

## 🔍 Troubleshooting

### Check Service Status
```bash
# Main application
docker-compose -f configs/docker-compose.production.yml ps

# RSS service
docker-compose -f configs/docker-compose.rss-service.yml ps
```

### View Logs
```bash
# Main application logs
docker-compose -f configs/docker-compose.production.yml logs

# RSS service logs
docker-compose -f configs/docker-compose.rss-service.yml logs
```

### Manual Health Checks
```bash
# Frontend
curl -f http://localhost:3000

# Backend
curl -f http://localhost:8000/health

# RSS Service
curl -f http://localhost:8001/health/public
```

## 🔄 Future: Auto-Deployment

When ready, we can enable automatic deployment by:
1. Setting up Cloudflare Tunnel for server access
2. Uncommenting deployment jobs in GitHub Actions
3. Configuring deployment secrets

## 📝 Notes

- The script is idempotent - safe to run multiple times
- Always pulls latest images before deploying
- Includes health checks to verify deployment success
- Uses Docker Compose for orchestration
- Supports both main app and RSS service deployment
