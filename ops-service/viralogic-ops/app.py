"""
Viralogic Ops Service - Enterprise Microservices API Gateway
===========================================================

Enterprise-grade centralized monitoring and operations service for all Viralogic microservices.
This service acts as a unified API gateway that can dynamically discover, monitor, and aggregate
data from any microservice, regardless of where it's deployed.

Key Features:
- Dynamic service registration and discovery
- Unified monitoring API for all microservices
- Centralized logging and metrics aggregation
- AI agent authentication and access control
- Future-proof architecture for infinite scalability
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
        structlog.stdlib.add_log_level,
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
    title="Viralogic Ops Service - Enterprise API Gateway",
    description="Centralized monitoring and operations for all Viralogic microservices",
    version="3.0.0",
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

# In-memory service registry (in production, use Redis or database)
REGISTERED_SERVICES = {}

# Default service configurations for known services
DEFAULT_SERVICES_CONFIG = {
    "main_app": {
        "backend": {
            "url": os.getenv("BACKEND_URL", "https://api.viralogic.io"),
            "health_endpoint": "/health",
            "monitoring_endpoint": "/api/v1/monitoring",
            "metrics_endpoint": "/metrics",
            "logs_endpoint": "/api/v1/logs",
            "register_endpoint": "/api/v1/register"
        },
        "frontend": {
            "url": os.getenv("FRONTEND_URL", "https://viralogic.io"),
            "health_endpoint": "/health",
            "metrics_endpoint": "/metrics",
            "logs_endpoint": "/api/v1/logs",
            "register_endpoint": "/api/v1/register"
        }
    },
    "rss_service": {
        "url": os.getenv("RSS_SERVICE_URL", "https://rss.viralogic.io"),
        "health_endpoint": "/health/public",
        "monitoring_endpoint": "/api/v1/health",
        "metrics_endpoint": "/metrics",
        "logs_endpoint": "/api/v1/logs",
        "register_endpoint": "/api/v1/register"
    },
    "ops_services": {
        "grafana": {
            "url": "http://ops-grafana:3000",
            "health_endpoint": "/api/health",
        },
        "prometheus": {
            "url": "http://ops-prometheus:1822",
            "health_endpoint": "/-/healthy",
            "metrics_endpoint": "/api/v1/query",
        },
        "loki": {
            "url": os.getenv("LOKI_URL", "http://ops-loki:1821"),
            "health_endpoint": "/ready",
            "logs_endpoint": "/loki/api/v1/query",
        },
        "alertmanager": {
            "url": "http://ops-alertmanager:1823",
            "health_endpoint": "/-/healthy",
        }
    }
}

def get_services_config():
    """Get merged configuration of default and registered services."""
    config = DEFAULT_SERVICES_CONFIG.copy()
    
    # Add registered services to appropriate groups
    for service_name, service_info in REGISTERED_SERVICES.items():
        group = service_info.get("group", "registered_services")
        if group not in config:
            config[group] = {}
        config[group][service_name] = service_info["config"]
    
    return config

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

class LogSubmission(BaseModel):
    service: str
    level: str
    message: str
    context: Optional[Dict[str, Any]] = None

class ServiceRegistration(BaseModel):
    service_name: str
    service_url: str
    group: str = "registered_services"
    health_endpoint: str = "/health"
    monitoring_endpoint: Optional[str] = None
    metrics_endpoint: Optional[str] = None
    logs_endpoint: Optional[str] = None
    capabilities: Optional[List[str]] = None
    metadata: Optional[Dict[str, Any]] = None

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
        logger.error("No API key provided")
        return False
    
    # Check if the provided key matches the configured key
    if x_api_key != AI_MONITORING_API_KEY:
        logger.error("Invalid API key provided")
        return False
    
    return True

# Service Discovery and Health Checking
async def check_service_health(service_name: str, config: Dict[str, Any]) -> ServiceHealth:
    """Check health of a specific service."""
    start_time = datetime.now()
    
    try:
        health_url = f"{config['url']}{config.get('health_endpoint', '/health')}"
        
        timeout = aiohttp.ClientTimeout(total=10)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            headers = {}
            if service_name == "backend" and AI_MONITORING_API_KEY:
                headers["x-api-key"] = AI_MONITORING_API_KEY
            
            async with session.get(health_url, headers=headers) as response:
                response_time = (datetime.now() - start_time).total_seconds() * 1000
                
                if response.status == 200:
                    data = await response.json()
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
                        error=f"HTTP {response.status}"
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
    services_config = get_services_config()
    
    # Check all service groups
    for group_name, group_config in services_config.items():
        for service_name, config in group_config.items():
            health_checks.append(check_service_health(service_name, config))
    
    return await asyncio.gather(*health_checks)

async def collect_system_metrics() -> Dict[str, Any]:
    """Collect system metrics from all available sources."""
    try:
        services_config = get_services_config()
        metrics = {
            "timestamp": datetime.now().isoformat(),
            "services": {},
            "overall": {
                "total_services": 0,
                "healthy_services": 0,
                "unhealthy_services": 0
            }
        }
        
        # Get health status for all services
        health_checks = await discover_all_services()
        
        for health in health_checks:
            metrics["services"][health.service] = {
                "status": health.status,
                "response_time_ms": health.response_time_ms,
                "last_check": health.timestamp.isoformat()
            }
            
            metrics["overall"]["total_services"] += 1
            if health.status == "healthy":
                metrics["overall"]["healthy_services"] += 1
            else:
                metrics["overall"]["unhealthy_services"] += 1
        
        return metrics
        
    except Exception as e:
        logger.error("System metrics collection failed", error=str(e))
        return {"error": str(e)}

# API Endpoints
@app.get("/")
async def ops_service_root():
    """Root endpoint with service information."""
    return {
        "service": "Viralogic Ops Service - Enterprise API Gateway",
        "version": "3.0.0",
        "description": "Centralized monitoring and operations for all Viralogic microservices",
        "timestamp": datetime.now().isoformat(),
        "architecture": "microservices_api_gateway",
        "endpoints": {
            "health": "/health",
            "overview": "/api/overview",
            "services": "/api/services",
            "register": "/api/v1/register",
            "logs": "/api/logs",
            "monitoring": "/api/monitoring",
            "metrics": "/api/metrics",
            "alerts": "/api/alerts"
        },
        "authentication": {
            "ai_agent": "x-api-key header required for /api/* endpoints",
            "public": "No auth required for /health endpoint"
        },
        "registered_services": len(REGISTERED_SERVICES),
        "default_services": sum(len(group) for group in DEFAULT_SERVICES_CONFIG.values())
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
            "version": "3.0.0",
            "ai_auth_configured": bool(AI_MONITORING_API_KEY),
            "services_monitored": sum(len(group) for group in get_services_config().values()),
            "registered_services": len(REGISTERED_SERVICES)
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
        raise HTTPException(status_code=500, detail=f"System overview failed: {str(e)}")

@app.get("/api/services")
async def get_all_services(
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Get all registered and configured services."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    try:
        services_config = get_services_config()
        services = []
        
        for group_name, group_config in services_config.items():
            for service_name, config in group_config.items():
                services.append({
                    "name": service_name,
                    "group": group_name,
                    "url": config["url"],
                    "endpoints": {
                        "health": config.get("health_endpoint", "/health"),
                        "monitoring": config.get("monitoring_endpoint"),
                        "metrics": config.get("metrics_endpoint"),
                        "logs": config.get("logs_endpoint")
                    },
                    "capabilities": config.get("capabilities", []),
                    "metadata": config.get("metadata", {})
                })
        
        return {
            "services": services,
            "total_services": len(services),
            "registered_services": len(REGISTERED_SERVICES),
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error("Service listing failed", error=str(e))
        raise HTTPException(status_code=500, detail=f"Service listing failed: {str(e)}")

@app.post("/api/v1/register")
async def register_service(
    registration: ServiceRegistration,
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Register a new microservice with the ops service."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    try:
        # Store service registration
        REGISTERED_SERVICES[registration.service_name] = {
            "config": {
                "url": registration.service_url,
                "health_endpoint": registration.health_endpoint,
                "monitoring_endpoint": registration.monitoring_endpoint,
                "metrics_endpoint": registration.metrics_endpoint,
                "logs_endpoint": registration.logs_endpoint,
                "capabilities": registration.capabilities or [],
                "metadata": registration.metadata or {}
            },
            "group": registration.group,
            "registered_at": datetime.now().isoformat()
        }
        
        logger.info("Service registered", 
                   service=registration.service_name, 
                   url=registration.service_url,
                   group=registration.group)
        
        return {
            "status": "registered",
            "service": registration.service_name,
            "message": f"Service {registration.service_name} successfully registered",
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error("Service registration failed", service=registration.service_name, error=str(e))
        raise HTTPException(status_code=500, detail=f"Service registration failed: {str(e)}")

@app.get("/api/v1/services/registered")
async def get_registered_services(
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Get all dynamically registered services."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    return {
        "services": REGISTERED_SERVICES,
        "total_registered": len(REGISTERED_SERVICES),
        "timestamp": datetime.now().isoformat()
    }

@app.post("/api/v1/logs")
async def submit_logs(
    log_submission: LogSubmission,
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Submit logs from a microservice."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    try:
        # Store log entry (in production, send to Loki or other log aggregation)
        log_entry = LogEntry(
            timestamp=datetime.now(),
            level=log_submission.level,
            service=log_submission.service,
            message=log_submission.message,
            context=log_submission.context
        )
        
        logger.info("Log submitted", 
                   service=log_submission.service,
                   level=log_submission.level,
                   message=log_submission.message)
        
        return {
            "status": "received",
            "log_id": f"{log_submission.service}_{datetime.now().timestamp()}",
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error("Log submission failed", service=log_submission.service, error=str(e))
        raise HTTPException(status_code=500, detail=f"Log submission failed: {str(e)}")

@app.get("/api/logs")
async def get_logs(
    service: str = Query(None, description="Filter by service name"),
    level: str = Query(None, description="Filter by log level"),
    hours: int = Query(24, description="Hours to look back"),
    limit: int = Query(100, description="Maximum number of logs to return"),
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Get logs from Loki or other log aggregation system."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    try:
        # Calculate time range
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=hours)
        
        # Build Loki query
        query_parts = []
        if service:
            query_parts.append(f'{{service="{service}"}}')
        if level:
            query_parts.append(f'{{level="{level}"}}')
        
        if not query_parts:
            query = '{service=~".+"}'
        else:
            query = " | ".join(query_parts)
        
        # Get Loki configuration
        services_config = get_services_config()
        loki_config = services_config["ops_services"]["loki"]
        loki_url = loki_config["url"]
        
        # Build Loki API URL
        params = {
            "query": query,
            "start": start_time.isoformat(),
            "end": end_time.isoformat(),
            "limit": limit
        }
        
        # Make request to Loki
        timeout = aiohttp.ClientTimeout(total=30)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            headers = {}
            if os.getenv("LOKI_USERNAME") and os.getenv("LOKI_PASSWORD"):
                import base64
                credentials = f"{os.getenv('LOKI_USERNAME')}:{os.getenv('LOKI_PASSWORD')}"
                encoded = base64.b64encode(credentials.encode()).decode()
                headers["Authorization"] = f"Basic {encoded}"
            
            async with session.get(f"{loki_url}/loki/api/v1/query_range", headers=headers, params=params) as response:
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
    services_config = get_services_config()
    
    for group_name, group_config in services_config.items():
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
        services_config = get_services_config()
        prometheus_config = services_config["ops_services"]["prometheus"]
        
        # Query Prometheus for basic system metrics
        queries = [
            "up",  # Service up status
            "http_requests_total",  # HTTP request metrics
            "process_cpu_seconds_total",  # CPU usage
            "process_resident_memory_bytes",  # Memory usage
        ]
        
        metrics_data = {}
        timeout = aiohttp.ClientTimeout(total=30)
        
        async with aiohttp.ClientSession(timeout=timeout) as session:
            for query in queries:
                try:
                    params = {"query": query}
                    async with session.get(f"{prometheus_config['url']}/api/v1/query", params=params) as response:
                        if response.status == 200:
                            data = await response.json()
                            metrics_data[query] = data
                        else:
                            metrics_data[query] = {"error": f"HTTP {response.status}"}
                except Exception as e:
                    metrics_data[query] = {"error": str(e)}
        
        return {
            "metrics": metrics_data,
            "timestamp": datetime.now().isoformat(),
            "source": "prometheus"
        }
        
    except Exception as e:
        logger.error("System metrics retrieval failed", error=str(e))
        raise HTTPException(status_code=500, detail=f"System metrics retrieval failed: {str(e)}")

@app.get("/api/alerts")
async def get_alerts(
    auth: bool = Depends(verify_ai_agent_auth)
):
    """Get active alerts from AlertManager."""
    if not auth:
        raise HTTPException(status_code=401, detail="AI agent authentication required")
    
    try:
        services_config = get_services_config()
        alertmanager_config = services_config["ops_services"]["alertmanager"]
        
        timeout = aiohttp.ClientTimeout(total=15)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.get(f"{alertmanager_config['url']}/api/v1/alerts") as response:
                if response.status == 200:
                    data = await response.json()
                    return {
                        "alerts": data,
                        "timestamp": datetime.now().isoformat(),
                        "source": "alertmanager"
                    }
                else:
                    raise HTTPException(
                        status_code=response.status,
                        detail=f"AlertManager returned {response.status}"
                    )
                    
    except Exception as e:
        logger.error("Alerts retrieval failed", error=str(e))
        raise HTTPException(status_code=500, detail=f"Alerts retrieval failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=1825)