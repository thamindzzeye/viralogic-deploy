# Local Deployment Guide

This guide explains how to use the local deployment setup to bypass GitHub Container Registry and build directly from source code.

## 🚀 Quick Start

```bash
# Deploy everything locally
./deploy-local.sh

# Stop all services
./deploy-local.sh stop
```

## 📁 File Structure

```
viralogic-deploy/
├── docker-compose-main-local.yml      # Main app with local builds
├── docker-compose-rss-local.yml       # RSS service with local builds
├── deploy-local.sh                    # Local deployment script
├── .env                               # Environment variables
└── cloudflared/                       # Cloudflare tunnel configs
```

## 🔧 Prerequisites

1. **Docker & Docker Compose** installed
2. **Viralogic source code** cloned at `../Viralogic` (same level as viralogic-deploy)
3. **Environment file** (`.env`) with all required variables
4. **Cloudflare tunnel credentials** in `cloudflared/` directory

## 📋 Directory Structure

```
/opt/
├── viralogic-deploy/                  # This repository
│   ├── docker-compose-main-local.yml
│   ├── docker-compose-rss-local.yml
│   ├── deploy-local.sh
│   └── .env
└── Viralogic/                         # Main source code
    ├── backend/
    ├── frontend/
    └── micro-services/rss-service/
```

## 🎯 Benefits of Local Deployment

### ✅ Advantages
- **No GitHub Container Registry dependency**
- **Faster iteration** (no 1.5 hour builds)
- **Immediate testing** of changes
- **Full control** over build process
- **Debugging** at build time

### ⚠️ Considerations
- **Longer initial build** (builds everything from scratch)
- **Requires source code** on production server
- **Manual updates** needed when source changes

## 🔄 Workflow

### 1. Development
```bash
# Make changes in Viralogic repository
cd /opt/Viralogic
# ... make changes ...

# Test locally
./deploy-local.sh
```

### 2. Production Deployment
```bash
# Deploy with local builds
cd /opt/viralogic-deploy
./deploy-local.sh
```

### 3. Rebuilding Specific Services
```bash
# Rebuild only backend
docker-compose -f docker-compose-main-local.yml up -d --build backend

# Rebuild only frontend
docker-compose -f docker-compose-main-local.yml up -d --build frontend

# Rebuild RSS service
docker-compose -f docker-compose-rss-local.yml up -d --build rss-service
```

## 📊 Comparison: Local vs Git Builds

| Aspect | Local Build | Git Build |
|--------|-------------|-----------|
| **Speed** | 5-15 minutes | 1.5 hours |
| **Dependencies** | Requires source code | Pulls from registry |
| **Iteration** | Immediate | Push → Wait → Pull |
| **Control** | Full build control | Pre-built images |
| **Debugging** | Build-time debugging | Runtime only |

## 🛠️ Troubleshooting

### Build Failures
```bash
# Check build logs
docker-compose -f docker-compose-main-local.yml logs backend

# Rebuild with no cache
docker-compose -f docker-compose-main-local.yml build --no-cache backend
```

### Service Issues
```bash
# Check service status
docker-compose -f docker-compose-main-local.yml ps

# View logs
docker-compose -f docker-compose-main-local.yml logs -f
```

### Environment Issues
```bash
# Verify .env file
cat .env

# Check environment variables in container
docker-compose -f docker-compose-main-local.yml exec backend env
```

## 🔄 Migration Between Local and Git Builds

### Switch to Local Builds
```bash
# Stop git-based services
./deploy.sh stop

# Start local builds
./deploy-local.sh
```

### Switch Back to Git Builds
```bash
# Stop local services
./deploy-local.sh stop

# Start git-based services
./deploy.sh
```

## 📝 Environment Variables

The local deployment uses the same `.env` file as the git-based deployment. All environment variables are passed as build arguments to the Docker build process.

### Required Variables
- Database credentials
- Redis passwords
- API keys
- OAuth credentials
- MinIO configuration
- Service URLs

## 🎯 Best Practices

1. **Use local builds for development** and testing
2. **Use git builds for production** once stable
3. **Keep source code updated** on production server
4. **Monitor build times** and optimize Dockerfiles
5. **Use specific rebuilds** for faster iteration

## 🚀 Next Steps

Once you're confident with the local deployment:

1. **Optimize Dockerfiles** for faster builds
2. **Set up CI/CD** for automated git builds
3. **Implement blue-green deployment** strategy
4. **Add monitoring** and alerting
