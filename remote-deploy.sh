#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SERVER_HOST="$1"
SERVER_USER="${2:-ubuntu}"
KEY_PATH="${3:-./n8n-server-key.pem}"

if [ -z "$SERVER_HOST" ]; then
  echo "Usage: ./remote-deploy.sh <SERVER_IP> [USER] [KEY_PATH]"
  exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
  echo "Error: Key file '$KEY_PATH' not found."
  exit 1
fi

chmod 600 "$KEY_PATH"
REMOTE_TARGET="${SERVER_USER}@${SERVER_HOST}"
REMOTE_DIR="/home/${SERVER_USER}/n8n-server"

echo "Connecting to $REMOTE_TARGET..."
ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" "$REMOTE_TARGET" "mkdir -p $REMOTE_DIR"

echo "Syncing repository files..."
rsync -avz -e "ssh -o StrictHostKeyChecking=no -i $KEY_PATH" \
  --exclude '.git' \
  --exclude '*.pem' \
  --exclude 'postgres_data' \
  --exclude 'redis_data' \
  --exclude 'data' \
  --exclude 'backups' \
  --exclude '.DS_Store' \
  ./ "$REMOTE_TARGET:$REMOTE_DIR/"

echo "Running server setup and deploy..."
ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" "$REMOTE_TARGET" << 'EOF'
  set -e
  cd ~/n8n-server
  if ! command -v docker &> /dev/null; then
    bash setup-server.sh
  fi
  bash deploy.sh
EOF

echo "Remote deployment successfully completed on $SERVER_HOST!"
