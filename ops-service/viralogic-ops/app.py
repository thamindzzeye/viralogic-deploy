"""
Viralogic Ops Service
====================

Enterprise-grade centralized monitoring and operations service.
This service aggregates data from all Viralogic services and provides
a unified API for monitoring, logging, analytics, and performance data.

Architecture:
- Single entry point: ops.viralogic.io
- Service discovery and aggregation
- AI agent authentication
- Future-proof for new services
- Works across multiple machines
"""

import os
import logging
import asyncio
import aiohttp
import json
from typing import Dict, Any, Optional, List, Union
from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException, Header, Depends, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import structlog

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlog.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer(),
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger(__name__)

app = FastAPI(
    title="Viralogic Ops Service",
    description="Centralized monitoring and operations for all Viralogic services",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
AI_MONITORING_API_KEY = os.getenv("AI_MONITORING_API_KEY")
SERVICES_CONFIG = {
    "main_app": {
        "backend": {
            "url": os.getenv("BACKEND_URL", "https://api.viralogic.io"),
            "health_endpoint": "/health",
            "monitoring_endpoint": "/api/v1/monitoring",
            "metrics_endpoint": "/metrics",
        },
        "frontend": {
            "url": os.getenv("FRONTEND_URL", "https://viralogic.io"),
            "health_endpoint": "/",
        }
    },
    "rss_service": {
        "url": os.getenv("RSS_SERVICE_URL", "https://rss.viralogic.io"),
        "health_endpoint": "/health/public",
        "monitoring_endpoint": "/api/v1/health",
        "metrics_endpoint": "/metrics",
    },
    "ops_services": {
        "grafana": {
            "url": "http://grafana:1820",
            "health_endpoint": "/api/health",
        },
        "prometheus": {
            "url": "http://prometheus:1822",
            "health_endpoint": "/-/healthy",
            "metrics_endpoint": "/api/v1/query",
        },
        "loki": {
            "url": os.getenv("LOKI_URL", "http://loki:1821"),
            "health_endpoint": "/ready",
            "logs_endpoint": "/loki/api/v1/query",
        },
        "alertmanager": {
            "url": "http://alertmanager:1823",
            "health_endpoint": "/-/healthy",
        }
    }
}

# Data Models
class ServiceHealth(BaseModel):
    service: str
    status: str
    timestamp: datetime
    response_time_ms: Optional[float] = None
    error: Optional[str] = None
    details: Optional[Dict[str, Any]] = None

class SystemOverview(BaseModel):
    overall_status: str
    services: List[ServiceHealth]
    timestamp: datetime
    ai_agent_authenticated: bool
    total_services: int
    healthy_services: int

class LogEntry(BaseModel):
    timestamp: datetime
    level: str
    service: str
    message: str
    context: Optional[Dict[str, Any]] = None

class MonitoringData(BaseModel):
    service: str
    endpoint: str
    data: Dict[str, Any]
    timestamp: datetime
    source: str

# Authentication
def verify_ai_agent_auth(x_api_key: str = Header(None)) -> bool:
    """Verify AI agent API key."""
    if not AI_MONITORING_API_KEY:
        logger.error("AI_MONITORING_API_KEY not configured")
        return False
    
    if not x_api_key:
        logger.warning("No API key provided")
        return False
    
    if x_api_key.strip() == AI_MONITORING_API_KEY.strip():
        logger.info("AI agent authenticated successfully")
        return True
    
    logger.warning("Invalid API key provided")
    return False

# Service Discovery and Health Checks
async def check_service_health(service_name: str, service_config: Dict[str, Any]) -> ServiceHealth:
    """Check health of a service with detailed information."""
    start_time = datetime.now()
    
    try:
        timeout = aiohttp.ClientTimeout(total=10)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            url = f"{service_config['url']}{service_config.get('health_endpoint', '/health')}"
            
            headers = {}
            # Add authentication if needed
            if service_name == "backend" and AI_MONITORING_API_KEY:
                headers["x-api-key"] = AI_MONITORING_API_KEY
            
            async with session.get(url, headers=headers) as response:
                response_time = (datetime.now() - start_time).total_seconds() * 1000
                
                if response.status == 200:
                    try:
                        data = await response.json()
                    except:
                        data = {"status": "healthy", "raw_response": await response.text()}
                    
                    return ServiceHealth(
                        service=service_name,
                        status="healthy",
                        timestamp=datetime.now(),
                        response_time_ms=response_time,
                        details=data
                    )
                else:
                    return ServiceHealth(
                        service=service_name,
                        status="unhealthy",
                        timestamp=datetime.now(),
                        response_time_ms=response_time,
                        error=f"HTTP {response.status}",
                        details={"status_code": response.status}
                    )
                    
    except Exception as e:
        response_time = (datetime.now() - start_time).total_seconds() * 1000
        logger.error("Health check failed", service=service_name, error=str(e))
        return ServiceHealth(
            service=service_name,
            status="unhealthy",
            timestamp=datetime.now(),
            response_time_ms=response_time,
            error=str(e)
        )

async def discover_all_services() -> List[ServiceHealth]:
    """Discover and check health of all configured services."""
    health_checks = []
    
    # Check main app services
    for service_name, config in SERVICES_CONFIG["main_app"].items():
        health_checks.append(check_service_health(service_name, config))
    
    # Check RSS service
    health_checks.append(check_service_health("rss_service", SERVICES_CONFIG["rss_service"]))
    
    # Check ops services
    for service_name, config in SERVICES_CONFIG["ops_services"].items():
        health_checks.append(check_service_health(service_name, config))
    
    return await asyncio.gather(*health_checks)

# API Endpoints
@app.get("/")
async def ops_service_root():
    """Root endpoint with service information."""
    return {
        "service": "Viralogic Ops Service",
        "version": "2.0.0",
        "description": "Centralized monitoring and operations for all Viralogic services",
        "timestamp": datetime.now().isoformat(),
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

@app.get("/health")
async def ops_health_check():
    """Public health check endpoint."""
    try:
        # Quick health check of ops service itself
        return {
            "status": "healthy",
            "service": "viralogic-ops",
            "timestamp": datetime.now().isoformat(),
            "version": "2.0.0",
            "ai_auth_configured": bool(AI_MONITORING_API_KEY),
            "services_monitored": sum(len(group) for group in SERVICES_CONFIG.values())
        }
    except Exception as e:
        logger.error("Ops health check failed", error=str(e))
        return {
            "status": "unhealthy",
            "service": "viralogic-ops",
            "timestamp": datetime.now().isoformat(),
            "error": str(e)
        }

@app.get("/api/overview")
async def get_system_overview(
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Get comprehensive system overview."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    try:
        services = await discover_all_services()
        
        healthy_services = [s for s in services if s.status == "healthy"]
        overall_status = "healthy" if len(healthy_services) == len(services) else "degraded"
        
        return SystemOverview(
            overall_status=overall_status,
            services=services,
            timestamp=datetime.now(),
            ai_agent_authenticated=True,
            total_services=len(services),
            healthy_services=len(healthy_services)
        )
        
    except Exception as e:
        logger.error("System overview failed", error=str(e))
        raise HTTPException(status_code=500, detail=f"Failed to get system overview: {str(e)}")

@app.get("/api/services")
async def get_services_status(
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Get status of all services."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    services = await discover_all_services()
    return {
        "services": services,
        "timestamp": datetime.now().isoformat(),
        "summary": {
            "total": len(services),
            "healthy": len([s for s in services if s.status == "healthy"]),
            "unhealthy": len([s for s in services if s.status == "unhealthy"])
        }
    }

@app.get("/api/services/{service_name}")
async def get_service_details(
    service_name: str,
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Get detailed information about a specific service."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    # Find service configuration
    service_config = None
    for group_name, group_config in SERVICES_CONFIG.items():
        if service_name in group_config:
            service_config = group_config[service_name]
            break
    
    if not service_config:
        raise HTTPException(status_code=404, detail=f"Service {service_name} not found")
    
    health = await check_service_health(service_name, service_config)
    
    return {
        "service": service_name,
        "health": health,
        "configuration": {
            "url": service_config["url"],
            "endpoints": {k: v for k, v in service_config.items() if k != "url"}
        },
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/logs")
async def get_logs(
    service: str = Query(None, description="Filter by service name"),
    level: str = Query("INFO", description="Log level filter"),
    hours: int = Query(24, description="Hours to look back"),
    limit: int = Query(100, description="Maximum number of logs"),
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Get logs from all services via Loki."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    try:
        # Query Loki for logs
        loki_config = SERVICES_CONFIG["ops_services"]["loki"]
        
        # Build query
        query = "{}"
        if service:
            query = f'{{service="{service}"}}'
        
        # Add level filter
        if level != "ALL":
            query += f' |= "{level}"'
        
        # Time range
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=hours)
        start_ns = int(start_time.timestamp() * 1_000_000_000)
        end_ns = int(end_time.timestamp() * 1_000_000_000)
        
        # Query Loki
        timeout = aiohttp.ClientTimeout(total=30)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            url = f"{loki_config['url']}/loki/api/v1/query_range"
            params = {
                "query": query,
                "start": start_ns,
                "end": end_ns,
                "limit": limit
            }
            
            # Add auth if configured
            headers = {}
            if os.getenv("LOKI_USERNAME") and os.getenv("LOKI_PASSWORD"):
                import base64
                credentials = f"{os.getenv('LOKI_USERNAME')}:{os.getenv('LOKI_PASSWORD')}"
                encoded = base64.b64encode(credentials.encode()).decode()
                headers["Authorization"] = f"Basic {encoded}"
            
            async with session.get(url, headers=headers, params=params) as response:
                if response.status == 200:
                    data = await response.json()
                    return {
                        "logs": data,
                        "query": query,
                        "time_range": {
                            "start": start_time.isoformat(),
                            "end": end_time.isoformat(),
                            "hours": hours
                        },
                        "filters": {
                            "service": service,
                            "level": level,
                            "limit": limit
                        },
                        "timestamp": datetime.now().isoformat()
                    }
                else:
                    error_text = await response.text()
                    logger.error("Loki query failed", status=response.status, error=error_text)
                    raise HTTPException(status_code=500, detail=f"Loki query failed: {response.status}")
                    
    except Exception as e:
        logger.error("Log retrieval failed", error=str(e))
        raise HTTPException(status_code=500, detail=f"Failed to retrieve logs: {str(e)}")

@app.get("/api/monitoring/{service_name}")
async def get_service_monitoring(
    service_name: str,
    endpoint: str = Query("health", description="Monitoring endpoint to call"),
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Get monitoring data from a specific service."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    # Find service configuration
    service_config = None
    for group_name, group_config in SERVICES_CONFIG.items():
        if service_name in group_config:
            service_config = group_config[service_name]
            break
    
    if not service_config:
        raise HTTPException(status_code=404, detail=f"Service {service_name} not found")
    
    try:
        # Determine endpoint URL
        endpoint_config = service_config.get(f"{endpoint}_endpoint", f"/{endpoint}")
        url = f"{service_config['url']}{endpoint_config}"
        
        # Make request with appropriate headers
        headers = {}
        if service_name == "backend" and AI_MONITORING_API_KEY:
            headers["x-api-key"] = AI_MONITORING_API_KEY
        
        timeout = aiohttp.ClientTimeout(total=15)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.get(url, headers=headers) as response:
                if response.status == 200:
                    data = await response.json()
                    return MonitoringData(
                        service=service_name,
                        endpoint=endpoint,
                        data=data,
                        timestamp=datetime.now(),
                        source=url
                    )
                else:
                    raise HTTPException(
                        status_code=response.status,
                        detail=f"Service {service_name} returned {response.status}"
                    )
                    
    except Exception as e:
        logger.error("Monitoring data retrieval failed", service=service_name, endpoint=endpoint, error=str(e))
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get monitoring data from {service_name}: {str(e)}"
        )

@app.get("/api/metrics")
async def get_system_metrics(
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Get system metrics from Prometheus."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    try:
        prometheus_config = SERVICES_CONFIG["ops_services"]["prometheus"]
        
        # Query Prometheus for basic system metrics
        queries = [
            "up",  # Service up status
            "http_requests_total",  # HTTP request metrics
            "process_cpu_seconds_total",  # CPU usage
            "process_resident_memory_bytes",  # Memory usage
        ]
        
        results = {}
        timeout = aiohttp.ClientTimeout(total=15)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            for query in queries:
                url = f"{prometheus_config['url']}{prometheus_config['metrics_endpoint']}"
                params = {"query": query}
                
                async with session.get(url, params=params) as response:
                    if response.status == 200:
                        data = await response.json()
                        results[query] = data
                    else:
                        results[query] = {"error": f"HTTP {response.status}"}
        
        return {
            "metrics": results,
            "timestamp": datetime.now().isoformat(),
            "source": "prometheus"
        }
        
    except Exception as e:
        logger.error("Metrics retrieval failed", error=str(e))
        raise HTTPException(status_code=500, detail=f"Failed to retrieve metrics: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=1825)
