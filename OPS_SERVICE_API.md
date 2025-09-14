# Viralogic Ops Service API Documentation

## Overview

The **Viralogic Ops Service** is the centralized monitoring and operations hub for all Viralogic services. It provides a unified API for monitoring, logging, analytics, and performance data across the entire platform.

**Base URL**: `https://ops.viralogic.io`

## Authentication

### AI Agent Authentication
All `/api/*` endpoints require AI agent authentication via the `x-api-key` header:

```bash
curl -H "x-api-key: viralogic-ai-uuqrOYQxuXlCGyYoz3uePzLEUwuaPaHLRlhG6IUgBmI" \
     https://ops.viralogic.io/api/overview
```

### Public Endpoints
The following endpoints require no authentication:
- `GET /` - Service information
- `GET /health` - Health check

## API Endpoints

### 1. Service Information

#### `GET /`
Get basic information about the ops service.

**Response:**
```json
{
  "service": "Viralogic Ops Service",
  "version": "2.0.0",
  "description": "Centralized monitoring and operations for all Viralogic services",
  "timestamp": "2025-01-14T00:00:00Z",
  "endpoints": {
    "health": "/health",
    "overview": "/api/overview",
    "services": "/api/services",
    "logs": "/api/logs",
    "monitoring": "/api/monitoring",
    "metrics": "/api/metrics",
    "alerts": "/api/alerts"
  },
  "authentication": {
    "ai_agent": "x-api-key header required for /api/* endpoints",
    "public": "No auth required for /health endpoint"
  }
}
```

#### `GET /health`
Public health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "service": "viralogic-ops",
  "timestamp": "2025-01-14T00:00:00Z",
  "version": "2.0.0",
  "ai_auth_configured": true,
  "services_monitored": 8
}
```

### 2. System Overview

#### `GET /api/overview`
Get comprehensive system overview with health status of all services.

**Authentication:** Required (AI Agent)

**Response:**
```json
{
  "overall_status": "healthy",
  "services": [
    {
      "service": "backend",
      "status": "healthy",
      "timestamp": "2025-01-14T00:00:00Z",
      "response_time_ms": 45.2,
      "details": {
        "status": "healthy",
        "app_name": "Viralogic API",
        "version": "1.0.0"
      }
    },
    {
      "service": "rss_service",
      "status": "healthy",
      "timestamp": "2025-01-14T00:00:00Z",
      "response_time_ms": 32.1,
      "details": {
        "status": "healthy",
        "service": "rss-service"
      }
    }
  ],
  "timestamp": "2025-01-14T00:00:00Z",
  "ai_agent_authenticated": true,
  "total_services": 8,
  "healthy_services": 8
}
```

### 3. Service Management

#### `GET /api/services`
Get status of all monitored services.

**Authentication:** Required (AI Agent)

**Response:**
```json
{
  "services": [
    {
      "service": "backend",
      "status": "healthy",
      "timestamp": "2025-01-14T00:00:00Z",
      "response_time_ms": 45.2,
      "details": {...}
    }
  ],
  "timestamp": "2025-01-14T00:00:00Z",
  "summary": {
    "total": 8,
    "healthy": 8,
    "unhealthy": 0
  }
}
```

#### `GET /api/services/{service_name}`
Get detailed information about a specific service.

**Authentication:** Required (AI Agent)

**Parameters:**
- `service_name` (path): Name of the service (backend, frontend, rss_service, grafana, prometheus, loki, alertmanager)

**Response:**
```json
{
  "service": "backend",
  "health": {
    "service": "backend",
    "status": "healthy",
    "timestamp": "2025-01-14T00:00:00Z",
    "response_time_ms": 45.2,
    "details": {...}
  },
  "configuration": {
    "url": "https://api.viralogic.io",
    "endpoints": {
      "health_endpoint": "/health",
      "monitoring_endpoint": "/api/v1/monitoring",
      "metrics_endpoint": "/metrics"
    }
  },
  "timestamp": "2025-01-14T00:00:00Z"
}
```

### 4. Logging

#### `GET /api/logs`
Get logs from all services via Loki.

**Authentication:** Required (AI Agent)

**Query Parameters:**
- `service` (optional): Filter by service name
- `level` (optional): Log level filter (INFO, WARN, ERROR, DEBUG, ALL)
- `hours` (optional): Hours to look back (default: 24)
- `limit` (optional): Maximum number of logs (default: 100)

**Example:**
```bash
curl -H "x-api-key: YOUR_API_KEY" \
     "https://ops.viralogic.io/api/logs?service=backend&level=ERROR&hours=1&limit=50"
```

**Response:**
```json
{
  "logs": {
    "status": "success",
    "data": {
      "resultType": "streams",
      "result": [...]
    }
  },
  "query": "{service=\"backend\"} |= \"ERROR\"",
  "time_range": {
    "start": "2025-01-14T23:00:00Z",
    "end": "2025-01-15T00:00:00Z",
    "hours": 1
  },
  "filters": {
    "service": "backend",
    "level": "ERROR",
    "limit": 50
  },
  "timestamp": "2025-01-15T00:00:00Z"
}
```

### 5. Monitoring Data

#### `GET /api/monitoring/{service_name}`
Get monitoring data from a specific service.

**Authentication:** Required (AI Agent)

**Parameters:**
- `service_name` (path): Name of the service
- `endpoint` (query): Monitoring endpoint to call (default: health)

**Example:**
```bash
# Get backend health
curl -H "x-api-key: YOUR_API_KEY" \
     "https://ops.viralogic.io/api/monitoring/backend"

# Get backend monitoring data
curl -H "x-api-key: YOUR_API_KEY" \
     "https://ops.viralogic.io/api/monitoring/backend?endpoint=monitoring"
```

**Response:**
```json
{
  "service": "backend",
  "endpoint": "health",
  "data": {
    "status": "healthy",
    "app_name": "Viralogic API",
    "version": "1.0.0",
    "timestamp": 1757809203.0843217
  },
  "timestamp": "2025-01-15T00:00:00Z",
  "source": "https://api.viralogic.io/health"
}
```

### 6. System Metrics

#### `GET /api/metrics`
Get system metrics from Prometheus.

**Authentication:** Required (AI Agent)

**Response:**
```json
{
  "metrics": {
    "up": {
      "status": "success",
      "data": {
        "resultType": "vector",
        "result": [...]
      }
    },
    "http_requests_total": {...},
    "process_cpu_seconds_total": {...},
    "process_resident_memory_bytes": {...}
  },
  "timestamp": "2025-01-15T00:00:00Z",
  "source": "prometheus"
}
```

## Service Discovery

The ops service automatically discovers and monitors the following services:

### Main Application Services
- **backend**: FastAPI application (`https://api.viralogic.io`)
- **frontend**: Next.js application (`https://viralogic.io`)

### RSS Service
- **rss_service**: RSS processing microservice (`https://rss.viralogic.io`)

### Ops Services
- **grafana**: Monitoring dashboards (`http://grafana:1820`)
- **prometheus**: Metrics collection (`http://prometheus:1822`)
- **loki**: Log aggregation (`http://loki:1821`)
- **alertmanager**: Alert handling (`http://alertmanager:1823`)

## Error Handling

All endpoints return appropriate HTTP status codes:

- `200`: Success
- `401`: Authentication required
- `404`: Service or endpoint not found
- `500`: Internal server error

Error responses include detailed error messages:

```json
{
  "detail": "AI agent authentication required"
}
```

## Rate Limiting

Currently no rate limiting is implemented, but it may be added in future versions.

## Future Enhancements

### Planned Features
- **Real-time Alerts**: Integration with AlertManager
- **Performance Analytics**: Advanced performance metrics
- **Custom Dashboards**: Dynamic dashboard creation
- **Service Mesh Integration**: Support for service mesh architectures
- **Multi-Environment Support**: Support for staging, production, etc.

### Adding New Services

To add a new service to monitoring:

1. Add service configuration to `SERVICES_CONFIG` in `app.py`
2. Deploy the service with appropriate health endpoints
3. The ops service will automatically discover and monitor it

Example service configuration:
```python
"new_service": {
    "url": "https://new-service.viralogic.io",
    "health_endpoint": "/health",
    "monitoring_endpoint": "/api/v1/monitoring",
    "metrics_endpoint": "/metrics"
}
```

## Security Considerations

- **API Key Security**: Store API keys securely in environment variables
- **Network Security**: All inter-service communication uses HTTPS
- **Access Control**: AI agents can only access monitoring data, not user data
- **Audit Logging**: All API access is logged for security auditing

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify `AI_MONITORING_API_KEY` is set correctly
   - Check API key format and length
   - Ensure no extra whitespace in API key

2. **Service Connectivity**
   - Verify service URLs in configuration
   - Check network connectivity between services
   - Verify service health endpoints are accessible

3. **Log Collection Issues**
   - Check Loki connectivity and authentication
   - Verify log volume and retention settings
   - Check Promtail configuration for log collection

### Health Check Commands

```bash
# Check ops service health
curl https://ops.viralogic.io/health

# Check system overview
curl -H "x-api-key: YOUR_API_KEY" \
     https://ops.viralogic.io/api/overview

# Check specific service
curl -H "x-api-key: YOUR_API_KEY" \
     https://ops.viralogic.io/api/services/backend

# Check logs
curl -H "x-api-key: YOUR_API_KEY" \
     "https://ops.viralogic.io/api/logs?hours=1&limit=10"
```
