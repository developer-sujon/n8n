#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================================="
echo "🚀 Initiating High-Scale Zero-Downtime n8n Deployment"
echo "=========================================================="

# 1. Check for .env file
if [ ! -f .env ]; then
  echo "❌ Error: .env file not found!"
  echo "👉 Please copy .env.example to .env:"
  echo "   cp .env.example .env"
  exit 1
fi

# Load environment variables
export $(grep -v '^#' .env | xargs)

# 2. Pull latest container images
echo "📦 Pulling latest Docker images..."
docker compose pull --quiet

# 3. Ensure database and message queue are running and healthy
echo "🐘 Ensuring PostgreSQL and Redis are healthy..."
docker compose up -d postgres redis

echo "⏳ Waiting for PostgreSQL and Redis readiness..."
until docker compose ps postgres | grep -q "(healthy)"; do
  sleep 1
done
until docker compose ps redis | grep -q "(healthy)"; do
  sleep 1
done
echo "✅ PostgreSQL and Redis are ready!"

# 4. Bring up core n8n services
echo "🔄 Updating and starting n8n main instance..."
docker compose up -d --no-deps n8n-main

# 5. Health check n8n-main
echo "⏳ Verifying n8n-main health probe..."
MAX_RETRIES=40
RETRY_COUNT=0
HEALTHY=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if docker compose ps n8n-main | grep -q "(healthy)"; then
    HEALTHY=1
    break
  fi
  sleep 2
  RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $HEALTHY -ne 1 ]; then
  echo "❌ n8n-main failed health checks! Checking logs:"
  docker compose logs --tail=40 n8n-main
  exit 1
fi
echo "✅ n8n-main passed health check!"

# 6. Bring up webhook and workers
echo "⚡ Deploying dedicated n8n Webhook service..."
docker compose up -d --no-deps n8n-webhook

echo "⚙️ Deploying n8n Queue Workers..."
WORKER_COUNT=${N8N_WORKERS:-2}
docker compose up -d --no-deps --scale n8n-worker="$WORKER_COUNT" n8n-worker

# 7. Start / Reload Nginx reverse proxy
if docker ps --format '{{.Names}}' | grep -q "n8n-proxy"; then
  echo "🔄 Reloading Nginx reverse proxy..."
  docker exec n8n-proxy nginx -s reload 2>/dev/null || docker compose up -d n8n-proxy
else
  echo "🌐 Starting Nginx reverse proxy..."
  docker compose up -d n8n-proxy
fi

# 8. Clean up unused images and stopped containers
echo "🧹 Pruning old unused Docker layers..."
docker image prune -f >/dev/null 2>&1 || true

echo "=========================================================="
echo "🎉 n8n High-Scale Deployment Successfully Completed!"
echo "   - Main Node: Running (Port 5678)"
echo "   - Webhook Node: Running"
echo "   - Worker Cluster: $WORKER_COUNT Workers"
echo "   - Proxy: Nginx Active on Port 80/443"
echo "=========================================================="
