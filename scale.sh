#!/usr/bin/env bash
set -e

COUNT=${1:-2}
echo "Scaling n8n queue workers to $COUNT..."
docker compose up -d --no-recreate --scale n8n-worker="$COUNT" n8n-worker
docker compose ps n8n-worker
