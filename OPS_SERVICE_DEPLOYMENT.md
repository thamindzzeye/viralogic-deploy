# Viralogic Ops Service Deployment Guide

## Overview

The **Viralogic Ops Service** is a centralized monitoring and operations hub that aggregates data from all Viralogic services. This guide covers the complete deployment process.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ops.viralogic.io                        │
│                  (Cloudflare Tunnel)                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              Viralogic Ops Service                          │
│                  (Port 1825)                               │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐          │
│  │   Health    │ │   Logs      │ │  Monitoring │          │
│  │   Checks    │ │   (Loki)    │ │  (Services) │          │
│  └─────────────┘ └─────────────┘ └─────────────┘          │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
┌───────▼──────┐ ┌───▼────┐ ┌──────▼──────┐
│   Backend    │ │   RSS  │ │    Grafana  │
│   Frontend   │ │ Service│ │ Prometheus  │
│              │ │        │ │    Loki     │
└──────────────┘ └────────┘ └─────────────┘
```

## Prerequisites

1. **Docker & Docker Compose**: Installed and running
2. **Cloudflare Account**: With tunnel access
3. **Domain**: `ops.viralogic.io` configured in Cloudflare
4. **Network Access**: Services must be reachable from ops service

## Deployment Steps

### 1. Environment Configuration

Copy the example environment file and configure it:

```bash
cd /path/to/viralogic-deploy/ops-service
cp env.example .env
```

Edit `.env` with your specific values:

```bash
# Required: AI Agent Authentication
AI_MONITORING_API_KEY=your-secure-api-key-here

# Required: Service URLs
BACKEND_URL=https://api.viralogic.io
FRONTEND_URL=https://viralogic.io
RSS_SERVICE_URL=https://rss.viralogic.io

# Required: Loki Configuration
LOKI_USERNAME=your-loki-username
LOKI_PASSWORD=your-loki-password
```

### 2. Cloudflare Tunnel Setup

#### Generate Tunnel Token
1. Go to Cloudflare Dashboard → Zero Trust → Access → Tunnels
2. Create new tunnel: `viralogic-ops-production`
3. Copy the tunnel token
4. Add token to `.env` file

#### Configure Tunnel Credentials
The tunnel credentials file should be placed at:
```
./cloudflared/viralogic-ops-production-tunnel.json
```

### 3. Build and Deploy

```bash
# Build the ops service
docker-compose -f docker-compose-ops.yml build viralogic-ops

# Start all services
docker-compose -f docker-compose-ops.yml up -d

# Check service health
docker-compose -f docker-compose-ops.yml ps
```

### 4. Verify Deployment

#### Check Ops Service Health
```bash
curl https://ops.viralogic.io/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "viralogic-ops",
  "timestamp": "2025-01-15T00:00:00Z",
  "version": "2.0.0",
  "ai_auth_configured": true,
  "services_monitored": 8
}
```

#### Test AI Agent Authentication
```bash
curl -H "x-api-key: your-api-key" \
     https://ops.viralogic.io/api/overview
```

#### Check Service Discovery
```bash
curl -H "x-api-key: your-api-key" \
     https://ops.viralogic.io/api/services
```

## Service Configuration

### Monitored Services

The ops service automatically monitors these services:

#### Main Application
- **Backend**: `https://api.viralogic.io`
  - Health: `/health`
  - Monitoring: `/api/v1/monitoring`
  - Metrics: `/metrics`

- **Frontend**: `https://viralogic.io`
  - Health: `/`

#### RSS Service
- **RSS Service**: `https://rss.viralogic.io`
  - Health: `/health/public`
  - Monitoring: `/api/v1/health`
  - Metrics: `/metrics`

#### Ops Services
- **Grafana**: `http://grafana:1820`
- **Prometheus**: `http://prometheus:1822`
- **Loki**: `http://loki:1821`
- **AlertManager**: `http://alertmanager:1823`

### Adding New Services

To add a new service, update the `SERVICES_CONFIG` in `viralogic-ops/app.py`:

```python
"new_service": {
    "url": "https://new-service.viralogic.io",
    "health_endpoint": "/health",
    "monitoring_endpoint": "/api/v1/monitoring",
    "metrics_endpoint": "/metrics"
}
```

Then rebuild and redeploy:
```bash
docker-compose -f docker-compose-ops.yml build viralogic-ops
docker-compose -f docker-compose-ops.yml up -d viralogic-ops
```

## API Endpoints

### Public Endpoints (No Auth)
- `GET /` - Service information
- `GET /health` - Health check

### AI Agent Endpoints (Auth Required)
- `GET /api/overview` - System overview
- `GET /api/services` - All services status
- `GET /api/services/{name}` - Specific service details
- `GET /api/logs` - Log aggregation
- `GET /api/monitoring/{service}` - Service monitoring data
- `GET /api/metrics` - System metrics

### Alternative Access
- `GET /grafana/*` - Direct Grafana access
- `GET /prometheus/*` - Direct Prometheus access
- `GET /loki/*` - Direct Loki access

## Monitoring & Logging

### Health Checks
- **Ops Service**: `curl https://ops.viralogic.io/health`
- **Docker Health**: `docker-compose -f docker-compose-ops.yml ps`
- **Service Discovery**: `curl -H "x-api-key: KEY" https://ops.viralogic.io/api/services`

### Logs
All services log to structured JSON format:
```bash
# View ops service logs
docker-compose -f docker-compose-ops.yml logs viralogic-ops

# View all ops logs
docker-compose -f docker-compose-ops.yml logs
```

### Metrics
- **Prometheus**: `https://ops.viralogic.io/prometheus/`
- **Grafana**: `https://ops.viralogic.io/grafana/`

## Troubleshooting

### Common Issues

#### 1. Service Unreachable
```bash
# Check service connectivity
curl -H "x-api-key: KEY" https://ops.viralogic.io/api/services/backend

# Check network connectivity
docker-compose -f docker-compose-ops.yml exec viralogic-ops curl https://api.viralogic.io/health
```

#### 2. Authentication Failures
```bash
# Verify API key
echo $AI_MONITORING_API_KEY

# Test authentication
curl -H "x-api-key: $AI_MONITORING_API_KEY" https://ops.viralogic.io/api/overview
```

#### 3. Log Collection Issues
```bash
# Check Loki connectivity
curl -H "x-api-key: KEY" https://ops.viralogic.io/api/logs?limit=1

# Check Loki health
curl https://ops.viralogic.io/loki/ready
```

#### 4. Cloudflare Tunnel Issues
```bash
# Check tunnel status
docker-compose -f docker-compose-ops.yml logs cloudflared-ops

# Verify tunnel credentials
ls -la ./cloudflared/
```

### Debug Commands

```bash
# Full system status
curl -H "x-api-key: KEY" https://ops.viralogic.io/api/overview

# Service-specific health
curl -H "x-api-key: KEY" https://ops.viralogic.io/api/services/backend

# Recent logs
curl -H "x-api-key: KEY" "https://ops.viralogic.io/api/logs?hours=1&limit=10"

# System metrics
curl -H "x-api-key: KEY" https://ops.viralogic.io/api/metrics
```

## Security Considerations

### API Key Management
- Store API keys in environment variables only
- Use strong, randomly generated keys
- Rotate keys regularly
- Never commit keys to version control

### Network Security
- All inter-service communication uses HTTPS
- Cloudflare tunnel provides DDoS protection
- Services run in isolated Docker networks

### Access Control
- AI agents can only access monitoring data
- No access to user data or sensitive operations
- All API access is logged for auditing

## Scaling Considerations

### Horizontal Scaling
- Ops service can be replicated behind load balancer
- Each instance monitors all services independently
- Stateless design allows easy scaling

### Service Mesh Integration
- Future enhancement for microservices
- Automatic service discovery
- Advanced traffic management

### Multi-Environment Support
- Staging and production environments
- Environment-specific configurations
- Isolated monitoring per environment

## Maintenance

### Regular Tasks
- Monitor service health daily
- Review logs weekly
- Update API keys monthly
- Scale resources as needed

### Updates
```bash
# Update ops service
docker-compose -f docker-compose-ops.yml build viralogic-ops
docker-compose -f docker-compose-ops.yml up -d viralogic-ops

# Update all services
docker-compose -f docker-compose-ops.yml pull
docker-compose -f docker-compose-ops.yml up -d
```

## Support

For issues or questions:
1. Check logs: `docker-compose -f docker-compose-ops.yml logs`
2. Verify configuration: `curl https://ops.viralogic.io/health`
3. Test API access: `curl -H "x-api-key: KEY" https://ops.viralogic.io/api/overview`
4. Review this documentation
5. Check Cloudflare tunnel status

## Future Enhancements

### Planned Features
- Real-time alerts via AlertManager
- Custom dashboard creation
- Performance analytics
- Service mesh integration
- Multi-environment support
- Advanced log analysis
- Automated incident response

### Integration Points
- Slack notifications
- Email alerts
- PagerDuty integration
- Custom webhooks
- External monitoring systems