# Ops Service Deployment Guide

## Overview
This document outlines the deployment of the new Ops Service for centralized logging and monitoring across all Viralogic services.

## What's Been Added

### 1. Ops Service Directory Structure
```
ops-service/
├── docker-compose-ops.yml          # Production deployment
├── docker-compose-ops-local.yml    # Local development deployment
├── config/                         # Configuration files
│   ├── loki/                      # Loki log aggregation config
│   ├── promtail/                  # Log collection config
│   └── grafana/                   # Dashboard and datasource config
├── cloudflared/                    # Cloudflare tunnel config
│   ├── config.yml
│   └── viralogic-ops-production-tunnel.json
├── start.sh                        # Startup script
└── README.md                       # Service documentation
```

### 2. Updated Docker Compose Files

#### Main Application Services
**Files Updated:**
- `Viralogic/docker-compose-main.yml` (Production)
- `Viralogic/docker-compose-main-local.yml` (Local)

**Services with Logging Added:**
- `postgres` - Database service
- `redis` - Cache service
- `backend` - FastAPI backend
- `frontend` - Next.js frontend
- `celeryworker` - Background worker
- `celerybeat` - Task scheduler
- `adminer` - Database admin
- `cloudflared-main` - Main app tunnel

#### RSS Service
**Files Updated:**
- `rss-service/docker-compose-rss.yml` (Production)
- `rss-service/docker-compose-rss-local.yml` (Local)

**Services with Logging Added:**
- `rss-postgres` - RSS database
- `rss-redis` - RSS cache
- `rss-service` - RSS main app
- `rss-celery-worker` - RSS background worker
- `rss-celery-beat` - RSS scheduler
- `rss-flower` - RSS Celery monitoring
- `rss-adminer` - RSS database admin
- `cloudflared-rss` - RSS tunnel

### 3. Logging Configuration Details

#### Log Driver Configuration
All services now include:
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
    labels: "logging_jobname=<service-name>,logging_stream=stdout"
```

#### Service Labels Applied
| Service | Label | Description |
|---------|-------|-------------|
| Main Backend | `backend` | FastAPI application |
| Main Frontend | `frontend` | Next.js application |
| RSS App | `rss-app` | RSS microservice |
| All Celery | `celeryworker`, `celerybeat` | Background workers |
| All Postgres | `postgres`, `rss-postgres` | Database services |
| All Redis | `redis`, `rss-redis` | Cache services |
| All Flower | `flower`, `rss-flower` | Celery monitoring |
| All Cloudflared | `cloudflared`, `rss-cloudflared` | Tunnel services |

## Deployment Instructions

### 1. Production Deployment

#### Deploy Ops Service
```bash
cd ops-service
docker-compose -f docker-compose-ops.yml up -d
```

#### Deploy Main Application
```bash
cd Viralogic
docker-compose -f docker-compose-main.yml up -d
```

#### Deploy RSS Service
```bash
cd rss-service
docker-compose -f docker-compose-rss.yml up -d
```

### 2. Local Development Deployment

#### Deploy Ops Service
```bash
cd ops-service
docker-compose -f docker-compose-ops-local.yml up -d
```

#### Deploy Main Application
```bash
cd Viralogic
docker-compose -f docker-compose-main-local.yml up -d
```

#### Deploy RSS Service
```bash
cd rss-service
docker-compose -f docker-compose-rss-local.yml up -d
```

## Access Points

### Ops Service
- **Grafana Dashboard**: http://localhost:3000 (admin/admin123)
- **Loki API**: http://localhost:3100
- **Promtail**: http://localhost:9080
- **Production URL**: https://ops.viralogic.io (via Cloudflare tunnel)

### Main Application
- **Frontend**: https://viralogic.tbdv.org
- **Backend API**: https://viralogic-api.tbdv.org
- **Adminer**: http://localhost:1800

### RSS Service
- **RSS API**: https://rss.viralogic.io
- **RSS Adminer**: http://localhost:1801
- **RSS Flower**: http://localhost:1727

## Environment Variables

### Ops Service
Add to your `.env` file:
```bash
# Ops Service Configuration
OPS_GRAFANA_PASSWORD=your-secure-password-here
```

### Cloudflare Tunnel
Update the tunnel configuration:
```bash
# In ops-service/cloudflared/viralogic-ops-production-tunnel.json
{
  "AccountTag": "your-account-tag",
  "TunnelSecret": "your-tunnel-secret",
  "TunnelID": "your-tunnel-id"
}
```

## Monitoring and Maintenance

### Health Checks
```bash
# Check Ops Service health
curl http://localhost:3100/ready  # Loki
curl http://localhost:3000/api/health  # Grafana

# Check all services
docker-compose ps
```

### Log Management
```bash
# View service logs
docker-compose logs -f <service-name>

# Check log volumes
docker volume ls | grep ops-service
```

### Backup and Recovery
```bash
# Backup Grafana data
docker run --rm -v ops-service_grafana-data:/data -v $(pwd):/backup alpine tar czf /backup/grafana-backup.tar.gz -C /data .

# Backup Loki data
docker run --rm -v ops-service_loki-data:/data -v $(pwd):/backup alpine tar czf /backup/loki-backup.tar.gz -C /data .
```

## Security Considerations

### Default Credentials
- **Grafana**: admin/admin123
- **⚠️ CRITICAL**: Change these before production deployment

### Network Security
- Ops service runs on isolated `ops-network`
- Only necessary ports exposed
- Internal communication via Docker networks

### Access Control
- Cloudflare tunnel provides secure external access
- Zero trust configuration recommended
- IP restrictions and device posture checks

## Troubleshooting

### Common Issues

#### 1. No Logs Appearing
```bash
# Check Promtail configuration
docker-compose logs promtail

# Verify Docker socket access
docker exec ops-promtail ls /var/run/docker.sock
```

#### 2. Grafana Not Loading
```bash
# Check Grafana logs
docker-compose logs grafana

# Verify Loki connection
curl http://localhost:3100/ready
```

#### 3. Service Discovery Issues
```bash
# Check network connectivity
docker network ls
docker network inspect ops-network
```

### Debug Commands
```bash
# Check all container logs
docker-compose logs -f

# Inspect specific service
docker inspect <container-name>

# Check log driver configuration
docker inspect <container-name> | grep -A 10 "LogConfig"
```

## Performance Optimization

### Resource Requirements
- **CPU**: 2-4 cores for basic setup, 8+ for production
- **Memory**: 4-8GB RAM for basic setup, 16GB+ for production
- **Storage**: SSD storage for logs and metrics

### Scaling Considerations
- Multiple Loki instances for high log volume
- Data partitioning by time and service
- Caching with Redis for frequently accessed data

## Next Steps

### Phase 2: Enhanced Monitoring
- [ ] Add Prometheus for metrics collection
- [ ] Create operational dashboards
- [ ] Implement business metrics

### Phase 3: Advanced Features
- [ ] Add distributed tracing with Jaeger
- [ ] Implement ML-based anomaly detection
- [ ] Create executive dashboards

### Phase 4: Production Hardening
- [ ] Implement proper authentication
- [ ] Add backup automation
- [ ] Set up alerting and notifications

## Support and Documentation

### Additional Resources
- [Ops Service README](../ops-service/README.md)
- [Logging Updates Summary](../ops-service/LOGGING_UPDATES.md)
- [Main Project Documentation](../README.md)

### Contact Information
- **Architecture Owner**: [Your Name]
- **Technical Lead**: [Engineering Lead]
- **Operations Team**: [DevOps Team]

---

*This deployment provides enterprise-grade observability with zero ongoing costs and complete control over your monitoring infrastructure.*

