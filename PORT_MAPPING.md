# Viralogic Port Mapping

This document outlines all port mappings for the Viralogic platform deployment.

## Port Allocation Strategy

- **1720-1724**: Main application services
- **1725-1729**: RSS service (standalone microservice)
- **External ports = Internal ports** for all services

## Main Application (`docker-compose-main.yml`)

| Service | External Port | Internal Port | Description |
|---------|---------------|---------------|-------------|
| Backend API | 1720 | 1720 | FastAPI application |
| Frontend | 1721 | 1721 | Next.js application |
| PostgreSQL | 1723 | 1723 | Main database |
| Redis | 1724 | 1724 | Main cache |

### Internal Communication
- Backend → PostgreSQL: `postgres:1723`
- Backend → Redis: `redis:1724`
- Frontend → Backend: `backend:1720`

## RSS Service (`docker-compose-rss.yml`)

| Service | External Port | Internal Port | Description |
|---------|---------------|---------------|-------------|
| RSS API | 1722 | 1722 | RSS service API |
| RSS PostgreSQL | 1725 | 1725 | RSS database |
| RSS Redis | 1726 | 1726 | RSS cache |
| RSS Flower | 1727 | 1727 | Celery monitoring |

### Internal Communication
- RSS API → RSS PostgreSQL: `rss-postgres:1725`
- RSS API → RSS Redis: `rss-redis:1726`
- RSS Worker → RSS PostgreSQL: `rss-postgres:1725`
- RSS Worker → RSS Redis: `rss-redis:1726`
- RSS Beat → RSS PostgreSQL: `rss-postgres:1725`
- RSS Beat → RSS Redis: `rss-redis:1726`
- RSS Flower → RSS Redis: `rss-redis:1726`

## Cloudflare Tunnel Configuration

### Main Application Tunnel
- **Tunnel Name**: `viralogic-production`
- **Domain**: `viralogic.tbdv.org` → `http://frontend:1721`
- **Domain**: `viralogic-api.tbdv.org` → `http://backend:1720`

### RSS Service Tunnel
- **Tunnel Name**: `viralogic-rss-production`
- **Domain**: `rss.viralogic.io` → `http://rss-service:1722`

## Health Check Endpoints

| Service | Health Check URL | Port |
|---------|------------------|------|
| Backend | `http://localhost:1720/health` | 1720 |
| Frontend | `http://localhost:1721` | 1721 |
| RSS API | `http://localhost:1722/health/public` | 1722 |
| RSS Flower | `http://localhost:1727` | 1727 |

## Network Isolation

- **Main Application**: `viralogic-network`
- **RSS Service**: `rss-service-network`

Each service runs in its own isolated network for security and independence.

## Port Conflicts

All ports are carefully chosen to avoid conflicts:
- **1720-1729**: Reserved for Viralogic services
- **No overlap** with common ports (80, 443, 3000, 8000, 5432, 6379, etc.)
- **Sequential allocation** for easy management

## Deployment Notes

- All services use **matching internal/external ports**
- **No port remapping** required
- **Easy debugging** with direct port access
- **Independent scaling** possible for each service
