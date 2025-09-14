# 🚀 Viralogic Production Deployment Guide

## 📋 Pre-Deployment Checklist

### ✅ **CRITICAL: Ensure All Services Are Ready**

1. **Backend Service** (`api.viralogic.io`)
   - ✅ Metrics endpoint: `/metrics`
   - ✅ Health endpoint: `/health`
   - ✅ Monitoring API: `/api/v1/monitoring/*`
   - ✅ AI agent authentication configured
   - ✅ Environment variables set:
     - `AI_MONITORING_API_KEY`
     - `LOKI_URL`
     - `LOKI_USERNAME`
     - `LOKI_PASSWORD`

2. **RSS Service** (`rss.viralogic.io`)
   - ✅ Metrics endpoint: `/metrics`
   - ✅ Health endpoint: `/health/public`
   - ✅ API-based communication ready
   - ✅ Can run on separate machine/location

3. **Frontend Service** (`viralogic.io`)
   - ✅ Health endpoint: `/health`
   - ✅ Metrics endpoint: `/metrics` (if available)

## 🏗️ **Production Architecture Overview**

```
┌─────────────────────────────────────────────────────────────┐
│                    PRODUCTION SETUP                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   Main Server   │    │  RSS Server     │                │
│  │                 │    │  (Scalable)     │                │
│  │ api.viralogic.io│    │ rss.viralogic.io│                │
│  │ viralogic.io    │    │                 │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│           └───────────┬───────────┘                        │
│                       │                                    │
│  ┌─────────────────────────────────────────────────────────┤
│  │              OPS SERVER                                 │
│  │                                                         │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  │   Grafana   │  │ Prometheus  │  │    Loki     │     │
│  │  │   :1820     │  │   :1822     │  │   :1821     │     │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │
│  │                                                         │
│  │  ┌─────────────┐  ┌─────────────┐                      │
│  │  │AlertManager │  │Viralogic Ops│                      │
│  │  │   :1823     │  │   :1825     │                      │
│  │  └─────────────┘  └─────────────┘                      │
│  │                                                         │
│  │  ┌─────────────────────────────────────────────────────┤
│  │  │           Cloudflare Tunnel                         │
│  │  │                                                     │
│  │  │  ops.viralogic.io → viralogic-ops:1825             │
│  │  │  ops.viralogic.io/grafana/* → grafana:1820         │
│  │  │  ops.viralogic.io/prometheus/* → prometheus:1822   │
│  │  │  ops.viralogic.io/loki/* → loki:1821               │
│  │  └─────────────────────────────────────────────────────┤
│  └─────────────────────────────────────────────────────────┤
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Deployment Steps**

### **Step 1: Deploy Main Application**
```bash
cd /path/to/viralogic-deploy/Viralogic
docker-compose -f docker-compose-main.yml up -d
```

### **Step 2: Deploy RSS Service**
```bash
cd /path/to/viralogic-deploy/rss-service
docker-compose -f docker-compose-rss.yml up -d
```

### **Step 3: Deploy Ops Service**
```bash
cd /path/to/viralogic-deploy/ops-service
docker-compose -f docker-compose-ops.yml up -d
```

## 📊 **Enterprise Dashboards Available**

### **1. 🚨 Failure Notifications Dashboard**
- **URL**: `https://ops.viralogic.io/grafana/d/viralogic-failures/viralogic-failure-notifications-alerts`
- **Purpose**: Real-time monitoring of ALL system failures
- **Features**:
  - Autopost execution failures by platform and schedule
  - AI service failures by model and provider
  - Celery task failures
  - Platform posting failures by account
  - Unhealthy schedules requiring immediate attention

### **2. 📈 Autopost Executions Dashboard**
- **URL**: `https://ops.viralogic.io/grafana/d/viralogic-autopost-executions/viralogic-autopost-executions-schedules`
- **Purpose**: Detailed autopost execution tracking
- **Features**:
  - **EXACTLY what you requested**: Shows if 8:15am autopost with 3 platforms was 100% successful
  - Success rates by schedule, platform, and organization
  - Detailed execution tracking with error types
  - Platform-specific posting duration and success rates
  - Schedule health status and execution timeline
  - Celery task execution monitoring

### **3. 🤖 AI Performance Dashboard**
- **URL**: `https://ops.viralogic.io/grafana/d/viralogic-ai-performance/viralogic-ai-performance-costs`
- **Purpose**: AI service performance and cost monitoring
- **Features**:
  - **OpenRouter performance metrics** (exactly what you requested)
  - AI service success rates by model and provider
  - Response times (95th and 50th percentiles)
  - Token usage tracking
  - **Cost monitoring in USD**
  - Content generation duration
  - Failure tracking by AI model

### **4. 📊 Business Metrics Dashboard**
- **URL**: `https://ops.viralogic.io/grafana/d/viralogic-business/viralogic-business-metrics-performance`
- **Purpose**: Overall system performance and business metrics
- **Features**:
  - Overall system success rates
  - Volume metrics (posts/min, entries/min)
  - Performance timing
  - Queue depths
  - Schedule execution rates

### **5. 🔍 Comprehensive Monitoring Dashboard**
- **URL**: `https://ops.viralogic.io/grafana/d/viralogic-comprehensive/viralogic-comprehensive-monitoring`
- **Purpose**: All system metrics in one place
- **Features**:
  - Real-time data collection
  - Performance tracking
  - System health overview

## 🚨 **Enterprise Alerting System**

### **Alert Categories:**
1. **Autopost Alerts**
   - Execution failures
   - High failure rates (>20%)
   - Schedule health issues
   - Platform posting failures

2. **AI Service Alerts**
   - Service failures
   - High failure rates (>10%)
   - Slow responses (>30s)
   - High costs (>$0.10/5min)

3. **Celery Task Alerts**
   - Task failures
   - High failure rates (>15%)
   - Slow execution (>300s)

4. **RSS Service Alerts**
   - Service errors
   - Feed processing failures
   - Feed health issues

5. **System Alerts**
   - Service down
   - High error rates (>5%)
   - High response times (>5s)

## 🔑 **API Access for AI Agents**

### **Authentication**
- **Header**: `x-api-key: viralogic-ai-uuqrOYQxuXlCGyYoz3uePzLEUwuaPaHLRlhG6IUgBmI`
- **Base URL**: `https://ops.viralogic.io`

### **Available Endpoints**
- `GET /health` - System health check
- `GET /api/overview` - System overview
- `GET /api/logs` - Log queries
- `POST /api/v1/logs` - Log submission
- `GET /api/v1/services/registered` - Registered services
- `POST /api/v1/register` - Service registration

## 🌐 **Production URLs**

### **Main Application**
- **Frontend**: https://viralogic.io
- **Backend API**: https://api.viralogic.io
- **RSS Service**: https://rss.viralogic.io

### **Monitoring & Operations**
- **Ops Service**: https://ops.viralogic.io
- **Grafana**: https://ops.viralogic.io/grafana
- **Prometheus**: https://ops.viralogic.io/prometheus
- **Loki**: https://ops.viralogic.io/loki

## 🔧 **Environment Variables Required**

### **Ops Service (.env)**
```bash
# AI Agent Monitoring Configuration
AI_MONITORING_API_KEY=viralogic-ai-uuqrOYQxuXlCGyYoz3uePzLEUwuaPaHLRlhG6IUgBmI

# Service URLs (API-based for scalability)
BACKEND_URL=https://api.viralogic.io
FRONTEND_URL=https://viralogic.io
RSS_SERVICE_URL=https://rss.viralogic.io

# Loki Log Service Configuration
LOKI_URL=http://loki:1821
LOKI_USERNAME=ricky@twobit.media
LOKI_PASSWORD=8112624136

# Monitoring Limits
MAX_LOG_LIMIT=1000
MAX_HOURS_LOOKBACK=24
```

## 🚀 **Scalability Features**

### **✅ API-Based Communication**
- All services communicate via HTTPS APIs
- RSS service can run on separate machine/location
- Future microservices can be added anywhere
- No network dependencies between services

### **✅ Service Discovery**
- Automatic service registration
- Health monitoring across all services
- Centralized metrics collection
- Unified logging system

### **✅ Enterprise-Grade Monitoring**
- Real-time failure notifications
- Detailed performance metrics
- Cost tracking and optimization
- Comprehensive alerting system

## 🎯 **Key Features Delivered**

✅ **Detailed Autopost Tracking**: See exactly if your 8:15am post with 3 platforms was 100% successful
✅ **Platform Success Rates**: Track success/failure for each platform individually  
✅ **AI Performance**: OpenRouter response times, success rates, costs
✅ **Centralized Failure Notifications**: All failures in one dashboard
✅ **Celery Task Monitoring**: Track all background tasks
✅ **Schedule Health**: Monitor all autopost schedules
✅ **Enterprise-Grade**: Rivals top companies' monitoring systems
✅ **Scalable Architecture**: Ready for multi-machine deployment
✅ **API-Based Communication**: Future-proof for any scale

## 🎉 **Ready for Production!**

The system is now **production-ready** with enterprise-grade monitoring that provides complete visibility into your autopost system, AI performance, and overall system health. All services communicate via APIs, making it infinitely scalable across machines and locations.

**Deploy with confidence!** 🚀
