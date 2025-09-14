"""
Monitoring Gateway Service
=========================

Centralized monitoring gateway that aggregates data from all Viralogic services.
This service runs in the ops-service and provides a unified API for monitoring
across all microservices (main app, RSS service, etc.).

Features:
- Proxy to backend/RSS monitoring endpoints
- AI agent authentication
- Data aggregation from multiple services
- Works across multiple machines via HTTP
- Unified monitoring API
"""

import os
import logging
import asyncio
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
import aiohttp
import json
from fastapi import FastAPI, HTTPException, Header, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Viralogic Monitoring Gateway",
    description="Centralized monitoring gateway for all Viralogic services",
    version="1.0.0"
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
BACKEND_URL = os.getenv("BACKEND_URL", "http://api.viralogic.io")
RSS_SERVICE_URL = os.getenv("RSS_SERVICE_URL", "http://rss.viralogic.io")
LOKI_URL = os.getenv("LOKI_URL", "http://loki:1821")
LOKI_USERNAME = os.getenv("LOKI_USERNAME")
LOKI_PASSWORD = os.getenv("LOKI_PASSWORD")
MAX_LOG_LIMIT = int(os.getenv("MAX_LOG_LIMIT", "1000"))
MAX_HOURS_LOOKBACK = int(os.getenv("MAX_HOURS_LOOKBACK", "24"))

# Service endpoints
SERVICE_ENDPOINTS = {
    "backend": {
        "base_url": BACKEND_URL,
        "health": "/health",
        "metrics": "/metrics",
        "monitoring": "/api/v1/monitoring"
    },
    "rss_service": {
        "base_url": RSS_SERVICE_URL,
        "health": "/health/public",
        "metrics": "/metrics"
    },
    "grafana": {
        "base_url": "http://grafana:1820",
        "health": "/api/health"
    },
    "prometheus": {
        "base_url": "http://prometheus:1822",
        "health": "/-/healthy"
    },
    "loki": {
        "base_url": LOKI_URL,
        "health": "/ready"
    }
}

class HealthStatus(BaseModel):
    service: str
    status: str
    timestamp: datetime
    response_time_ms: Optional[float] = None
    error: Optional[str] = None

class ServiceMetrics(BaseModel):
    service: str
    metrics: Dict[str, Any]
    timestamp: datetime

class MonitoringData(BaseModel):
    overall_status: str
    services: List[HealthStatus]
    timestamp: datetime
    ai_agent_authenticated: bool

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
    
    logger.warning(f"Invalid API key provided: {x_api_key[:10]}...")
    return False

async def check_service_health(service_name: str, endpoint_config: Dict[str, str]) -> HealthStatus:
    """Check health of a single service."""
    start_time = datetime.now()
    
    try:
        async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=10)) as session:
            url = f"{endpoint_config['base_url']}{endpoint_config['health']}"
            async with session.get(url) as response:
                response_time = (datetime.now() - start_time).total_seconds() * 1000
                
                if response.status == 200:
                    return HealthStatus(
                        service=service_name,
                        status="healthy",
                        timestamp=datetime.now(),
                        response_time_ms=response_time
                    )
                else:
                    return HealthStatus(
                        service=service_name,
                        status="unhealthy",
                        timestamp=datetime.now(),
                        response_time_ms=response_time,
                        error=f"HTTP {response.status}"
                    )
    except Exception as e:
        response_time = (datetime.now() - start_time).total_seconds() * 1000
        logger.error(f"Health check failed for {service_name}: {str(e)}")
        return HealthStatus(
            service=service_name,
            status="unhealthy",
            timestamp=datetime.now(),
            response_time_ms=response_time,
            error=str(e)
        )

async def get_service_metrics(service_name: str, endpoint_config: Dict[str, str]) -> Optional[ServiceMetrics]:
    """Get metrics from a service."""
    try:
        async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=10)) as session:
            url = f"{endpoint_config['base_url']}{endpoint_config.get('metrics', '/metrics')}"
            async with session.get(url) as response:
                if response.status == 200:
                    content = await response.text()
                    # Parse basic metrics (simplified)
                    metrics = {"raw_metrics": content[:1000]}  # Truncate for JSON response
                    return ServiceMetrics(
                        service=service_name,
                        metrics=metrics,
                        timestamp=datetime.now()
                    )
    except Exception as e:
        logger.error(f"Metrics collection failed for {service_name}: {str(e)}")
    
    return None

@app.get("/health")
async def gateway_health():
    """Gateway health check."""
    return {
        "status": "healthy",
        "service": "monitoring-gateway",
        "timestamp": datetime.now(),
        "version": "1.0.0"
    }

@app.get("/api/monitoring/overview")
async def get_monitoring_overview(
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Get overall monitoring overview."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    # Check all services in parallel
    health_checks = []
    for service_name, endpoint_config in SERVICE_ENDPOINTS.items():
        if "health" in endpoint_config:
            health_checks.append(check_service_health(service_name, endpoint_config))
    
    services = await asyncio.gather(*health_checks)
    
    # Determine overall status
    unhealthy_services = [s for s in services if s.status != "healthy"]
    overall_status = "healthy" if not unhealthy_services else "degraded"
    
    return MonitoringData(
        overall_status=overall_status,
        services=services,
        timestamp=datetime.now(),
        ai_agent_authenticated=True
    )

@app.get("/api/monitoring/health/{service_name}")
async def get_service_health(
    service_name: str,
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Get health status for a specific service."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    if service_name not in SERVICE_ENDPOINTS:
        raise HTTPException(status_code=404, detail=f"Service {service_name} not found")
    
    endpoint_config = SERVICE_ENDPOINTS[service_name]
    health_status = await check_service_health(service_name, endpoint_config)
    
    return health_status

@app.get("/api/monitoring/logs/production")
async def get_production_logs(
    hours: int = Query(24, ge=1, le=MAX_HOURS_LOOKBACK),
    limit: int = Query(100, ge=1, le=MAX_LOG_LIMIT),
    service: str = Query(None, description="Filter by service name"),
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Get production logs from Loki."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    try:
        # Build Loki query
        query = "{}"
        if service:
            query = f'{{logging_jobname=~".*{service}.*"}}'
        
        # Add time range
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=hours)
        
        # Convert to Unix timestamps (nanoseconds)
        start_ns = int(start_time.timestamp() * 1000000000)
        end_ns = int(end_time.timestamp() * 1000000000)
        
        # Query Loki
        async with aiohttp.ClientSession() as session:
            # Basic auth for Loki
            auth_header = None
            if LOKI_USERNAME and LOKI_PASSWORD:
                import base64
                credentials = f"{LOKI_USERNAME}:{LOKI_PASSWORD}"
                encoded_credentials = base64.b64encode(credentials.encode()).decode()
                auth_header = f"Basic {encoded_credentials}"
            
            headers = {}
            if auth_header:
                headers["Authorization"] = auth_header
            
            url = f"{LOKI_URL}/loki/api/v1/query_range"
            params = {
                "query": query,
                "start": start_ns,
                "end": end_ns,
                "limit": limit
            }
            
            async with session.get(url, headers=headers, params=params) as response:
                if response.status == 200:
                    data = await response.json()
                    return {
                        "status": "success",
                        "data": data,
                        "query": query,
                        "time_range": {
                            "start": start_time.isoformat(),
                            "end": end_time.isoformat(),
                            "hours": hours
                        },
                        "limit": limit,
                        "service_filter": service
                    }
                else:
                    error_text = await response.text()
                    logger.error(f"Loki query failed: {response.status} - {error_text}")
                    raise HTTPException(
                        status_code=500,
                        detail=f"Loki query failed: {response.status}"
                    )
    
    except Exception as e:
        logger.error(f"Log retrieval failed: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to retrieve logs: {str(e)}"
        )

@app.get("/api/monitoring/backend/{endpoint:path}")
async def proxy_backend_monitoring(
    endpoint: str,
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Proxy requests to backend monitoring endpoints."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    try:
        async with aiohttp.ClientSession() as session:
            url = f"{BACKEND_URL}/api/v1/monitoring/{endpoint}"
            headers = {"x-api-key": AI_MONITORING_API_KEY}
            
            async with session.get(url, headers=headers) as response:
                data = await response.json()
                return {
                    "status": "success",
                    "data": data,
                    "source": "backend",
                    "endpoint": endpoint
                }
    except Exception as e:
        logger.error(f"Backend proxy failed for {endpoint}: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Backend proxy failed: {str(e)}"
        )

@app.get("/api/monitoring/rss/{endpoint:path}")
async def proxy_rss_monitoring(
    endpoint: str,
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Proxy requests to RSS service monitoring endpoints."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    try:
        async with aiohttp.ClientSession() as session:
            url = f"{RSS_SERVICE_URL}/{endpoint}"
            
            async with session.get(url) as response:
                data = await response.json()
                return {
                    "status": "success",
                    "data": data,
                    "source": "rss_service",
                    "endpoint": endpoint
                }
    except Exception as e:
        logger.error(f"RSS proxy failed for {endpoint}: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"RSS proxy failed: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=1825)
