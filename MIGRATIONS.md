# Database Migrations in Viralogic Deployment

## Overview

This document explains how database migrations are handled during the deployment process. Previously, migrations were not automatically run, which caused database schema mismatches.

## What's Fixed

### Before (Broken)
- ❌ Deployments didn't run migrations
- ❌ Database schema remained outdated
- ❌ Code changes failed due to missing columns/fields
- ❌ Manual migration execution required

### After (Fixed)
- ✅ All deployment scripts now run migrations automatically
- ✅ Database schema stays in sync with code
- ✅ No more schema mismatch errors
- ✅ Automated migration execution with error handling

## Migration Process

### 1. Automatic Migration Execution

All deployment scripts now include a **Database Migration Phase** that:

1. **Waits for services to be ready** (20-30 seconds)
2. **Runs main application migrations** (`alembic upgrade head`)
3. **Runs RSS service migrations** (`alembic upgrade head`)
4. **Verifies migration success** with error handling
5. **Continues with health checks** only after migrations succeed

### 2. Migration Order

```
1. Deploy containers (main app + RSS service)
2. Wait for services to be ready
3. Run main application migrations
4. Run RSS service migrations
5. Continue with health checks and final status
```

### 3. Error Handling

If migrations fail:
- ❌ Script exits with error code
- 🔍 Shows current migration status for debugging
- 📝 Logs detailed error information
- 🚫 Prevents deployment from continuing with broken schema

## Updated Scripts

### Main Deployment Scripts

1. **`deploy.sh`** - Production deployment with migrations
2. **`deploy-local.sh`** - Local deployment with migrations  
3. **`deploy-artifacts.sh`** - Artifact deployment with migrations

### New Migration Script

4. **`run-migrations.sh`** - Standalone migration execution

## Usage

### Automatic Migration (Recommended)

```bash
# Production deployment (includes migrations)
./deploy.sh

# Local deployment (includes migrations)
./deploy-local.sh

# Artifact deployment (includes migrations)
./deploy-artifacts.sh
```

### Manual Migration (Troubleshooting)

```bash
# Run migrations only (requires running services)
./run-migrations.sh
```

## Migration Files

### Main Application
- **Location**: `Viralogic/` directory
- **Container**: `backend`
- **Command**: `python -m alembic upgrade head`
- **Config**: `alembic.ini` in backend container

### RSS Service
- **Location**: `rss-service/` directory
- **Container**: `rss-service`
- **Command**: `python -m alembic upgrade head`
- **Config**: `alembic.ini` in RSS service container

## Current Migration (005_new_queue_fields)

This migration adds:
- `ai_task_id` column to `content_generation_queue` table
- `queued_at` timestamp to `content_generation_queue` table
- Extends `source_url` field from 500 to 1000 characters in `social_post` table

### What This Fixes

1. **AI Content Generation Queue**: Now works properly with new fields
2. **Google News URLs**: No more "source_url too long" errors
3. **Database Schema**: Matches code expectations exactly

## Troubleshooting

### Migration Fails

1. **Check service status**:
   ```bash
   docker-compose -f Viralogic/docker-compose-main.yml ps
   docker-compose -f rss-service/docker-compose-rss.yml ps
   ```

2. **Check migration status**:
   ```bash
   docker-compose -f Viralogic/docker-compose-main.yml exec backend python -m alembic current
   docker-compose -f rss-service/docker-compose-rss.yml exec rss-service python -m alembic current
   ```

3. **Check logs**:
   ```bash
   docker-compose -f Viralogic/docker-compose-main.yml logs backend
   docker-compose -f rss-service/docker-compose-rss.yml logs rss-service
   ```

### Common Issues

1. **Services not ready**: Increase wait time in migration phase
2. **Database connection**: Verify PostgreSQL is running and accessible
3. **Permission issues**: Check container user permissions
4. **Migration conflicts**: Verify migration files are in correct order

## Best Practices

1. **Always run migrations** during deployment
2. **Test migrations** in development first
3. **Backup databases** before major migrations
4. **Monitor migration logs** for any issues
5. **Verify schema changes** after migration completion

## Verification

After successful migration:

1. **Check 3 AM schedule execution** in logs
2. **Monitor AI content generation queue** processing
3. **Verify social posts** move from "pending" to "completed"
4. **Confirm new fields** exist in database tables

## Support

If you encounter migration issues:

1. Check the migration logs in the deployment output
2. Verify all services are running and healthy
3. Use the standalone `run-migrations.sh` script for debugging
4. Check the database schema directly via Adminer (port 1800)
