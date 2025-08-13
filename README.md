# Viralogic Deployment Repository

Simple, production-ready deployment for the Viralogic platform.

## 🚀 Quick Start

```bash
# Clone this repository on your production server
git clone https://github.com/your-username/viralogic-deploy.git
cd viralogic-deploy

# Set up your environment
cp configs/env.production.example configs/.env.production
# Edit configs/.env.production with your actual values

# Deploy everything
./deploy.sh production deploy
```

## 📁 Repository Structure

```
viralogic-deploy/
├── deploy.sh                 # Main deployment script
├── scripts/
│   ├── setup.sh             # Server setup (Docker, etc.)
│   ├── monitor.sh           # Health monitoring
│   └── backup.sh            # Database backups
├── configs/
│   ├── .env.production      # Production environment variables
│   ├── env.production.example
│   └── cloudflare-tunnel.yml
└── templates/
    ├── docker-compose.production.yml
    └── docker-compose.rss-service.yml
```

## 🛠️ Commands

```bash
# Deploy to production
./deploy.sh production deploy

# Check status
./deploy.sh production status

# View logs
./deploy.sh production logs

# Update application
./deploy.sh production update

# Stop services
./deploy.sh production stop

# Restart services
./deploy.sh production restart

# Backup database
./deploy.sh production backup

# Monitor health
./deploy.sh production monitor
```

## 🔧 Prerequisites

- Docker & Docker Compose
- Git
- Cloudflare account (for tunnel)
- GitHub Container Registry access

## 📋 Setup Steps

1. **Server Setup**: Run `./scripts/setup.sh` to install dependencies
2. **Environment**: Configure `configs/.env.production`
3. **Cloudflare**: Set up tunnel configuration
4. **Deploy**: Run `./deploy.sh production deploy`

## 🔒 Security

- All secrets stored in `.env.production` (not committed to git)
- Cloudflare Tunnel for secure access
- Environment-specific configurations
- No hardcoded credentials in compose files

## 📊 Monitoring

- Health checks on all services
- Log aggregation
- Basic metrics collection
- Automated backups

## 🆘 Troubleshooting

```bash
# Check service status
docker-compose -f configs/docker-compose.production.yml ps

# View specific service logs
docker-compose -f configs/docker-compose.production.yml logs backend

# Restart specific service
docker-compose -f configs/docker-compose.production.yml restart backend
```

## 🔄 Updates

```bash
# Update to latest version
./deploy.sh production update

# Rollback if needed
./deploy.sh production rollback
```

## 📞 Support

For issues or questions:
1. Check the logs: `./deploy.sh production logs`
2. Review the main Viralogic repository documentation
3. Check Cloudflare tunnel status
