# Ops Service - Centralized Observability Platform

## Overview
The Ops Service is a centralized logging and monitoring microservice for Viralogic, providing enterprise-grade observability capabilities using 100% open-source tools.

## Quick Start

### Prerequisites
- Docker and Docker Compose installed
- Ports 3000, 3100, and 9080 available

### Start the Service
```bash
cd micro-services/ops-service
./start.sh
```

### Access the Dashboard
- **Grafana**: http://localhost:3000 (admin/admin123)
- **Loki API**: http://localhost:3100
- **Promtail**: http://localhost:9080

## Architecture

### Components
- **Loki**: Log aggregation and storage
- **Grafana**: Dashboard and visualization
- **Promtail**: Log collection agent

### Data Flow
```
[Your Services] → [Promtail] → [Loki] → [Grafana Dashboard]
```

## Configuration

### Log Collection
The service automatically collects logs from:
- Docker containers (via Docker socket)
- System logs (/var/log)
- Application logs (/var/log/apps)
- Custom log files (/var/log/custom)

### Dashboard Features
- **All Container Logs**: View logs from all services
- **Backend Service Logs**: Filtered view of backend logs
- **Frontend Service Logs**: Filtered view of frontend logs
- **Real-time Updates**: 5-second refresh rate
- **Advanced Filtering**: Search by container, job, or custom labels

## Integration with Existing Services

### 1. Structured Logging
Ensure your services output structured JSON logs:
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "level": "INFO",
  "service": "backend",
  "message": "User authenticated successfully",
  "user_id": "123",
  "org_id": "456"
}
```

### 2. Docker Logging
Your existing services should use JSON log driver:
```yaml
# In your service docker-compose.yml
services:
  backend:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### 3. HTTP Log Shipping (Optional)
For direct integration, send logs to Loki HTTP endpoint:
```bash
curl -X POST http://localhost:3100/loki/api/v1/push \
  -H "Content-Type: application/json" \
  -d '{
    "streams": [{
      "stream": {"service": "backend"},
      "values": [["'$(date +%s)000000000'", "Log message here"]]
    }]
  }'
```

## Management

### Start/Stop
```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# View logs
docker-compose logs -f
```

### Health Checks
```bash
# Check Loki
curl http://localhost:3100/ready

# Check Grafana
curl http://localhost:3000/api/health
```

### Data Persistence
- Logs are stored in Docker volumes
- Loki data: `loki-data`
- Grafana data: `grafana-data`

## Security Notes

### Default Credentials
- **Username**: admin
- **Password**: admin123

**⚠️ IMPORTANT**: Change these credentials before production use!

### Network Isolation
- Services run on isolated `ops-network`
- Only necessary ports exposed to host
- Internal communication via Docker network

## Troubleshooting

### Common Issues

#### 1. Port Already in Use
```bash
# Check what's using the port
lsof -i :3000
lsof -i :3100

# Stop conflicting services or change ports in docker-compose.yml
```

#### 2. Permission Denied
```bash
# Ensure Docker socket access
sudo usermod -aG docker $USER
# Log out and back in
```

#### 3. No Logs Appearing
```bash
# Check Promtail configuration
docker-compose logs promtail

# Verify Docker socket access
docker exec ops-promtail ls /var/run/docker.sock
```

### Log Locations
- **Service Logs**: `docker-compose logs [service-name]`
- **Container Logs**: `/var/lib/docker/containers/*/*.log`
- **System Logs**: `/var/log/*`

## Next Steps

### Phase 2: Enhanced Logging
- [ ] Standardize log formats across all services
- [ ] Add log parsing and field extraction
- [ ] Implement log-based alerting

### Phase 3: Metrics & Monitoring
- [ ] Add Prometheus for metrics collection
- [ ] Create operational dashboards
- [ ] Implement business metrics

### Phase 4: Advanced Features
- [ ] Add distributed tracing with Jaeger
- [ ] Implement ML-based anomaly detection
- [ ] Create executive dashboards

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Docker container logs
3. Check the main project documentation

## Contributing

When modifying this service:
1. Update the configuration files as needed
2. Test changes in development environment
3. Update this README with new features
4. Follow the project's coding standards
