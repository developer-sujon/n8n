#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SERVER_HOST="$1"
SERVER_USER="${2:-ubuntu}"
KEY_PATH="${3:-./n8n-server-key.pem}"

if [ -z "$SERVER_HOST" ]; then
  echo "Usage: ./remote-deploy.sh <SERVER_IP_OR_HOSTNAME> [USER] [KEY_PATH]"
  echo "Example: ./remote-deploy.sh 130.94.54.66 ubuntu ./n8n-server-key.pem"
  exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
  echo "❌ Error: SSH key not found at '$KEY_PATH'!"
  exit 1
fi

# Ensure correct key permissions
chmod 600 "$KEY_PATH"

REMOTE_TARGET="${SERVER_USER}@${SERVER_HOST}"
REMOTE_DIR="/home/${SERVER_USER}/n8n-server"

echo "=========================================================="
echo "🚀 Deploying n8n to remote server: $REMOTE_TARGET"
echo "=========================================================="

# Test SSH connection
echo "📡 Testing SSH connectivity..."
ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" "$REMOTE_TARGET" "echo '✅ SSH Connected successfully!'"

# Ensure remote directory exists
ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" "$REMOTE_TARGET" "mkdir -p $REMOTE_DIR"

# Rsync files to remote
echo "📦 Syncing configuration and deployment files..."
rsync -avz -e "ssh -o StrictHostKeyChecking=no -i $KEY_PATH" \
  --exclude '.git' \
  --exclude '*.pem' \
  --exclude 'postgres_data' \
  --exclude 'redis_data' \
  --exclude 'data' \
  --exclude 'backups' \
  --exclude '.DS_Store' \
  ./ "$REMOTE_TARGET:$REMOTE_DIR/"

# Execute remote setup and deployment
echo "🚀 Executing remote deployment on server..."
ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" "$REMOTE_TARGET" << 'EOF'
  set -e
  cd ~/n8n-server

  # Run server preparation if Docker isn't installed
  if ! command -v docker &> /dev/null; then
    echo "⚡ First-time server setup detected. Running setup-server.sh..."
    bash setup-server.sh
  fi

  # Run zero-downtime deployment
  bash deploy.sh
EOF

echo "=========================================================="
echo "🎉 Remote deployment successfully completed on $SERVER_HOST!"
echo "=========================================================="
