# Ops Service Deployment Options

## Overview
The ops service supports two deployment methods to accommodate different build strategies:

1. **Local Builds** (`docker-compose-ops-local.yml`) - Build locally, copy to production
2. **Git Builds** (`docker-compose-ops.yml`) - Build directly from Git repositories

## Deployment Methods

### Method 1: Local Builds (Early Stage)
**File**: `docker-compose-ops-local.yml`
**Use Case**: Development and early production stages
**Build Process**: Build locally, copy artifacts to production server

```bash
# Deploy with local builds
cd /path/to/viralogic-deploy/ops-service
docker-compose -f docker-compose-ops-local.yml up -d
```

**Features**:
- Uses local Docker images
- Faster iteration during development
- Same monitoring capabilities as production
- Cloudflare tunnel: `viralogic-ops-dev`

### Method 2: Git Builds (Production)
**File**: `docker-compose-ops.yml`
**Use Case**: Production with automated Git-based builds
**Build Process**: Build directly from Git repositories

```bash
# Deploy with Git builds
cd /path/to/viralogic-deploy/ops-service
docker-compose -f docker-compose-ops.yml up -d
```

**Features**:
- Uses Git-based Docker images
- Automated CI/CD integration
- Production-ready monitoring
- Cloudflare tunnel: `viralogic-ops-production`

## Services Included (Both Methods)

### Core Monitoring Stack
- **Loki**: Log aggregation and storage
- **Grafana**: Dashboard and visualization
- **Promtail**: Log collection agent
- **Prometheus**: Metrics collection and storage
- **AlertManager**: Alert handling and notifications

### Access Points
- **Grafana Dashboard**: `https://ops.viralogic.io`
- **Prometheus**: `http://localhost:9090` (production server)
- **AlertManager**: `http://localhost:9093` (production server)

## Configuration Files

### Shared Configuration
Both deployment methods use the same configuration files:
- `config/prometheus/prometheus.yml` - Prometheus configuration
- `config/prometheus/rules/autopost-alerts.yml` - Alert rules
- `config/alertmanager/alertmanager.yml` - AlertManager configuration
- `config/grafana/dashboards/autopost-monitoring.json` - Autopost dashboard
- `config/grafana/provisioning/datasources/loki.yml` - Grafana datasources

### Volume Mounts
Both methods use the same volume structure:
- `../../docker_volumes/ops-service/loki:/loki`
- `../../docker_volumes/ops-service/grafana:/var/lib/grafana`
- `../../docker_volumes/ops-service/prometheus:/prometheus`
- `../../docker_volumes/ops-service/alertmanager:/alertmanager`

## Migration Path

### Phase 1: Local Builds (Current)
```bash
# Use local builds for development and early production
docker-compose -f docker-compose-ops-local.yml up -d
```

### Phase 2: Git Builds (Future)
```bash
# Switch to Git builds for production
docker-compose -f docker-compose-ops-local.yml down
docker-compose -f docker-compose-ops.yml up -d
```

## Monitoring Features (Both Methods)

### Autopost Monitoring
- **LinkedIn Posting Health**: Success/failure rates, processing times
- **Platform-Specific Dashboards**: LinkedIn, Twitter, Facebook monitoring
- **Real-time Alerts**: Automated notifications for failures
- **Trace Correlation**: Unique trace IDs for debugging

### API Endpoints
- `GET /api/v1/monitoring/autopost/status` - Comprehensive status
- `GET /api/v1/monitoring/autopost/health` - Simple health check
- `GET /api/v1/monitoring/autopost/failures` - Recent failures

### Grafana Dashboards
- **Viralogic Logs Overview** - General log viewing
- **Viralogic Autopost Monitoring** - Autopost-specific monitoring

## Health Checks

### Service Health
```bash
# Check Loki
curl http://localhost:3100/ready

# Check Grafana
curl http://localhost:3000/api/health

# Check Prometheus
curl http://localhost:9090/-/healthy

# Check AlertManager
curl http://localhost:9093/-/healthy
```

### Application Health
```bash
# Check autopost health via API
curl https://viralogic-api.tbdv.org/api/v1/monitoring/autopost/health
```

## Troubleshooting

### Common Issues
1. **Port Conflicts**: Ensure ports 3000, 3100, 9090, 9093 are available
2. **Volume Permissions**: Check Docker volume permissions
3. **Network Issues**: Verify `ops-network` is created properly

### Logs
```bash
# View service logs
docker-compose -f docker-compose-ops-local.yml logs -f
docker-compose -f docker-compose-ops.yml logs -f

# View specific service logs
docker-compose -f docker-compose-ops-local.yml logs -f grafana
docker-compose -f docker-compose-ops-local.yml logs -f prometheus
```

## Security Notes

### Default Credentials
- **Grafana**: admin/admin123
- **⚠️ CRITICAL**: Change these credentials before production use!

### Network Security
- Services run on isolated `ops-network`
- Only necessary ports exposed
- Internal communication via Docker networks
- Cloudflare tunnel provides secure external access

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Docker container logs
3. Check the main project documentation
4. Verify configuration files are properly mounted
