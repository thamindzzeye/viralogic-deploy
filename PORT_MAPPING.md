# Viralogic Port Mapping

This document outlines all port mappings for the Viralogic platform deployment.

## Port Allocation Strategy

- **1720-1724**: Main application services
- **1725-1729**: RSS service (standalone microservice)
- **1800-1809**: Monitoring and management tools
- **1820-1829**: Ops service (monitoring, logging, metrics)
- **External ports = Internal ports** for all services

## Main Application (`docker-compose-main.yml`)

| Service | External Port | Internal Port | Description |
|---------|---------------|---------------|-------------|
| Backend API | 1720 | 1720 | FastAPI application |
| Frontend | 1721 | 1721 | Next.js application |
| PostgreSQL | 1723 | 1723 | Main database |
| Redis | 1724 | 1724 | Main cache |
| Adminer | 1800 | 1800 | Database management interface |

### Internal Communication
- Backend → PostgreSQL: `postgres:1723`
- Backend → Redis: `redis:1724`
- Frontend → Backend: `backend:1720`
- Adminer → PostgreSQL: `postgres:1723`

## RSS Service (`docker-compose-rss.yml`)

| Service | External Port | Internal Port | Description |
|---------|---------------|---------------|-------------|
| RSS API | 1722 | 1722 | RSS service API |
| RSS PostgreSQL | 1725 | 1725 | RSS database |
| RSS Redis | 1726 | 1726 | RSS cache |
| RSS Flower | 1727 | 1727 | Celery monitoring |
| RSS Adminer | 1801 | 1801 | RSS database management interface |

### Internal Communication
- RSS API → RSS PostgreSQL: `rss-postgres:1725`
- RSS API → RSS Redis: `rss-redis:1726`
- RSS Worker → RSS PostgreSQL: `rss-postgres:1725`
- RSS Worker → RSS Redis: `rss-redis:1726`
- RSS Beat → RSS PostgreSQL: `rss-postgres:1725`
- RSS Beat → RSS Redis: `rss-redis:1726`
- RSS Flower → RSS Redis: `rss-redis:1726`
- RSS Adminer → RSS PostgreSQL: `rss-postgres:1725`

## Ops Service (`docker-compose-ops.yml`)

| Service | External Port | Internal Port | Description |
|---------|---------------|---------------|-------------|
| Grafana | 1820 | 1820 | Monitoring dashboards |
| Loki | 1821 | 1821 | Log aggregation |
| Prometheus | 1822 | 1822 | Metrics collection |
| AlertManager | 1823 | 1823 | Alert handling |
| Monitoring Gateway | 1825 | 1825 | Centralized monitoring API |

### Internal Communication
- Grafana → Loki: `loki:1821`
- Grafana → Prometheus: `prometheus:1822`
- Prometheus → Backend: `backend:1720` (via external network)
- Prometheus → RSS Service: `rss-service:1722` (via external network)
- Promtail → Loki: `loki:1821`
- Monitoring Gateway → All Services: HTTP calls to external URLs
- Monitoring Gateway → Loki: `loki:1821`

## Cloudflare Tunnel Configuration

### Main Application Tunnel
- **Tunnel Name**: `viralogic-production`
- **Domain**: `viralogic.io` → `http://frontend:1721`
- **Domain**: `api.viralogic.io` → `http://backend:1720`

### RSS Service Tunnel
- **Tunnel Name**: `viralogic-rss-production`
- **Domain**: `rss.viralogic.io` → `http://rss-service:1722`

### Ops Service Tunnel
- **Tunnel Name**: `viralogic-ops-production`
- **Domain**: `ops.viralogic.io` → `http://grafana:1820` (default)
- **Domain**: `ops.viralogic.io/api/monitoring/*` → `http://monitoring-gateway:1825`
- **Domain**: `ops.viralogic.io/health` → `http://monitoring-gateway:1825`
- **Domain**: `ops.viralogic.io/prometheus/*` → `http://prometheus:1822`
- **Domain**: `ops.viralogic.io/loki/*` → `http://loki:1821`

## Health Check Endpoints

| Service | Health Check URL | Port |
|---------|------------------|------|
| Backend | `http://localhost:1720/health` | 1720 |
| Frontend | `http://localhost:1721` | 1721 |
| RSS API | `http://localhost:1722/health/public` | 1722 |
| RSS Flower | `http://localhost:1727` | 1727 |
| Main Adminer | `http://localhost:1800` | 1800 |
| RSS Adminer | `http://localhost:1801` | 1801 |

## Database Access

### Main Database (Adminer)
- **URL**: `http://localhost:1800`
- **Server**: `postgres` (auto-filled)
- **Database**: `viralogic`
- **Username**: From environment variables
- **Password**: From environment variables

### RSS Database (Adminer)
- **URL**: `http://localhost:1801`
- **Server**: `rss-postgres` (auto-filled)
- **Database**: `rss_service`
- **Username**: From environment variables
- **Password**: From environment variables

## Network Isolation

- **Main Application**: `viralogic-network`
- **RSS Service**: `rss-service-network`

Each service runs in its own isolated network for security and independence.

## Port Conflicts

All ports are carefully chosen to avoid conflicts:
- **1720-1729**: Reserved for Viralogic services
- **1800-1809**: Reserved for monitoring and management tools
- **No overlap** with common ports (80, 443, 3000, 8000, 5432, 6379, etc.)
- **Sequential allocation** for easy management

## Deployment Notes

- All services use **matching internal/external ports**
- **No port remapping** required
- **Easy debugging** with direct port access
- **Independent scaling** possible for each service
- **Database access** available via Adminer on ports 1800 and 1801
