#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f .env ]; then
  echo "Error: .env file not found. Copy .env.example to .env first."
  exit 1
fi

set -a
# shellcheck disable=SC1091
[ -f .env ] && . .env 2>/dev/null || true
set +a

# Prepare directories and fix permissions for n8n container user (UID 1000)
echo "Preparing data directory permissions..."
mkdir -p ./data/n8n_main ./postgres_data ./redis_data ./backups
sudo chown -R 1000:1000 ./data 2>/dev/null || chown -R 1000:1000 ./data 2>/dev/null || true
chmod -R 775 ./data 2>/dev/null || true

echo "Pulling latest Docker images..."
docker compose pull --quiet

echo "Ensuring PostgreSQL and Redis are ready..."
docker compose up -d postgres redis

until docker compose ps postgres | grep -q "(healthy)"; do
  sleep 1
done
until docker compose ps redis | grep -q "(healthy)"; do
  sleep 1
done

echo "Starting n8n main..."
docker compose up -d --no-deps n8n-main

echo "Verifying health..."
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
  echo "n8n-main failed health checks!"
  docker compose logs --tail=40 n8n-main
  exit 1
fi

echo "Starting n8n webhook and workers..."
docker compose up -d --no-deps n8n-webhook

WORKER_COUNT=${N8N_WORKERS:-2}
docker compose up -d --no-deps --scale n8n-worker="$WORKER_COUNT" n8n-worker

if docker ps --format '{{.Names}}' | grep -q "n8n-proxy"; then
  docker exec n8n-proxy nginx -s reload 2>/dev/null || docker compose up -d n8n-proxy
else
  docker compose up -d n8n-proxy
fi

docker image prune -f >/dev/null 2>&1 || true

echo "n8n deployment complete! Active workers: $WORKER_COUNT"
