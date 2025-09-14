# Viralogic Monitoring Architecture

## Overview

This document describes the centralized monitoring architecture for the Viralogic platform, designed for scalability and multi-machine deployment.

## Architecture Components

### 1. Main Application (`Viralogic/`)
- **Backend API**: FastAPI application with monitoring endpoints
- **Frontend**: Next.js application
- **Database**: PostgreSQL + Redis
- **Workers**: Celery workers for background tasks
- **Access**: `api.viralogic.io` (Backend), `viralogic.io` (Frontend)

### 2. RSS Service (`rss-service/`)
- **RSS API**: Dedicated microservice for RSS processing
- **Database**: Separate PostgreSQL + Redis
- **Workers**: RSS-specific Celery workers
- **Access**: `rss.viralogic.io`

### 3. Ops Service (`ops-service/`)
- **Grafana**: Monitoring dashboards
- **Loki**: Log aggregation and storage
- **Prometheus**: Metrics collection
- **AlertManager**: Alert handling and notifications
- **Monitoring Gateway**: Centralized monitoring API
- **Access**: `ops.viralogic.io`

## Monitoring Gateway

The **Monitoring Gateway** is a new FastAPI service that provides:

### Features
- **Unified API**: Single endpoint for all monitoring data
- **AI Agent Authentication**: Secure access for AI agents
- **Service Aggregation**: Combines data from all services
- **Cross-Service Monitoring**: Works across multiple machines
- **Log Integration**: Direct access to Loki logs
- **Health Checks**: Real-time service health monitoring

### API Endpoints

#### Authentication
All endpoints require AI agent authentication via `x-api-key` header:
```
x-api-key: viralogic-ai-uuqrOYQxuXlCGyYoz3uePzLEUwuaPaHLRlhG6IUgBmI
```

#### Available Endpoints

| Endpoint | Description | Method |
|----------|-------------|---------|
| `/health` | Gateway health check | GET |
| `/api/monitoring/overview` | Overall system status | GET |
| `/api/monitoring/health/{service}` | Specific service health | GET |
| `/api/monitoring/logs/production` | Production logs from Loki | GET |
| `/api/monitoring/backend/{endpoint}` | Proxy to backend monitoring | GET |
| `/api/monitoring/rss/{endpoint}` | Proxy to RSS monitoring | GET |

#### Example Usage

```bash
# Get overall system status
curl -H "x-api-key: viralogic-ai-uuqrOYQxuXlCGyYoz3uePzLEUwuaPaHLRlhG6IUgBmI" \
     https://ops.viralogic.io/api/monitoring/overview

# Get production logs
curl -H "x-api-key: viralogic-ai-uuqrOYQxuXlCGyYoz3uePzLEUwuaPaHLRlhG6IUgBmI" \
     "https://ops.viralogic.io/api/monitoring/logs/production?hours=24&limit=100"

# Check specific service health
curl -H "x-api-key: viralogic-ai-uuqrOYQxuXlCGyYoz3uePzLEUwuaPaHLRlhG6IUgBmI" \
     https://ops.viralogic.io/api/monitoring/health/backend
```

## Network Architecture

### Current Setup (Single Machine)
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Main App      │    │   RSS Service   │    │   Ops Service   │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Backend API │ │    │ │ RSS API     │ │    │ │ Grafana     │ │
│ │ Frontend    │ │    │ │ Workers     │ │    │ │ Loki        │ │
│ │ Workers     │ │    │ │ Database    │ │    │ │ Prometheus  │ │
│ │ Database    │ │    │ │             │ │    │ │ Gateway     │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Cloudflare     │
                    │  Tunnels        │
                    │                 │
                    │ api.viralogic.io│
                    │ viralogic.io    │
                    │ rss.viralogic.io│
                    │ ops.viralogic.io│
                    └─────────────────┘
```

### Future Multi-Machine Setup
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Machine 1     │    │   Machine 2     │    │   Machine 3     │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Main App    │ │    │ │ RSS Service │ │    │ │ Ops Service │ │
│ │             │ │    │ │             │ │    │ │             │ │
│ │ Backend     │ │    │ │ RSS API     │ │    │ │ Grafana     │ │
│ │ Frontend    │ │    │ │ Workers     │ │    │ │ Loki        │ │
│ │ Workers     │ │    │ │ Database    │ │    │ │ Prometheus  │ │
│ │ Database    │ │    │ │             │ │    │ │ Gateway     │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Load Balancer  │
                    │  / DNS          │
                    │                 │
                    │ api.viralogic.io│
                    │ viralogic.io    │
                    │ rss.viralogic.io│
                    │ ops.viralogic.io│
                    └─────────────────┘
```

## Deployment

### 1. Environment Setup

Copy the environment template and configure:
```bash
cd ops-service
cp env.example .env
# Edit .env with your values
```

### 2. Deploy Ops Service
```bash
cd ops-service
docker-compose -f docker-compose-ops.yml up -d
```

### 3. Verify Deployment
```bash
# Check gateway health
curl https://ops.viralogic.io/health

# Check monitoring overview (requires API key)
curl -H "x-api-key: YOUR_API_KEY" \
     https://ops.viralogic.io/api/monitoring/overview
```

## Security Considerations

### AI Agent Authentication
- **API Key**: Cryptographically secure key for AI agents
- **Environment Variable**: Stored securely in `.env` files
- **Header-Based**: Uses `x-api-key` header for authentication
- **Logging**: All authentication attempts are logged

### Network Security
- **Isolated Networks**: Each service runs in its own Docker network
- **External Access**: Only through Cloudflare tunnels
- **Internal Communication**: HTTP calls with authentication
- **No Direct Database Access**: All access through APIs

### Data Privacy
- **Log Filtering**: Sensitive data is filtered from logs
- **Access Control**: AI agents can only access monitoring data
- **Audit Trail**: All monitoring access is logged
- **Data Retention**: Configurable log retention periods

## Scaling Considerations

### Horizontal Scaling
- **Stateless Services**: All services are stateless and can be scaled horizontally
- **Load Balancing**: Cloudflare provides automatic load balancing
- **Database Scaling**: Each service has its own database that can be scaled independently
- **Worker Scaling**: Celery workers can be scaled based on load

### Multi-Machine Deployment
- **Service Discovery**: Services communicate via HTTP using configured URLs
- **Network Isolation**: Each machine can run different services
- **Centralized Monitoring**: Ops service can monitor services across multiple machines
- **Independent Scaling**: Each service can be deployed on different machines

### Performance Optimization
- **Caching**: Redis caching for frequently accessed data
- **Async Processing**: Celery for background task processing
- **Connection Pooling**: Database connection pooling for optimal performance
- **Resource Limits**: Docker resource limits prevent resource exhaustion

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify `AI_MONITORING_API_KEY` is set correctly
   - Check API key format and length
   - Ensure no extra whitespace in API key

2. **Service Connectivity**
   - Verify service URLs in environment variables
   - Check network connectivity between services
   - Verify Cloudflare tunnel configuration

3. **Log Collection Issues**
   - Check Loki connectivity and authentication
   - Verify Promtail configuration
   - Check log volume and retention settings

### Monitoring Health Checks

```bash
# Check all services
curl -H "x-api-key: YOUR_API_KEY" \
     https://ops.viralogic.io/api/monitoring/overview

# Check specific service
curl -H "x-api-key: YOUR_API_KEY" \
     https://ops.viralogic.io/api/monitoring/health/backend

# Check logs
curl -H "x-api-key: YOUR_API_KEY" \
     "https://ops.viralogic.io/api/monitoring/logs/production?hours=1&limit=10"
```

## Future Enhancements

### Planned Features
- **Real-time Alerts**: Integration with AlertManager for real-time notifications
- **Custom Dashboards**: Dynamic dashboard creation based on service metrics
- **Performance Analytics**: Advanced performance analysis and reporting
- **Auto-scaling**: Automatic scaling based on monitoring metrics

### Integration Opportunities
- **External Monitoring**: Integration with external monitoring services
- **CI/CD Integration**: Monitoring integration with deployment pipelines
- **Business Metrics**: Integration with business intelligence tools
- **Compliance Reporting**: Automated compliance and audit reporting
