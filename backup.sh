#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/n8n_backup_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "🐘 Taking PostgreSQL dump for n8n..."
docker exec n8n-postgres pg_dump -U n8n -d n8n | gzip > "$BACKUP_FILE"

echo "✅ Backup successfully created at: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"

# Retention: keep last 14 days of backups
echo "🧹 Removing backups older than 14 days..."
find "$BACKUP_DIR" -type f -name "n8n_backup_*.sql.gz" -mtime +14 -delete
echo "✨ Backup job finished!"
