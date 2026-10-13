#!/usr/bin/env bash
set -e

echo "=========================================================="
echo "🛠️ Setting up Production VPS Environment for n8n"
echo "=========================================================="

# 1. Update OS packages
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release git ufw fail2ban

# 2. Install Docker & Docker Compose Plugin
if ! command -v docker &> /dev/null; then
  echo "🐳 Installing Docker Engine..."
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Enable docker service
  sudo systemctl enable docker
  sudo systemctl start docker

  # Add current user to docker group
  sudo usermod -aG docker "$USER" || true
  echo "✅ Docker installed successfully."
else
  echo "✅ Docker is already installed."
fi

# 3. Configure kernel sysctl settings for Redis and High-Throughput Networking
echo "⚙️ Optimizing system kernel parameters..."
sudo tee /etc/sysctl.d/99-n8n-performance.conf > /dev/null <<EOF
vm.overcommit_memory = 1
net.core.somaxconn = 65535
fs.file-max = 2097152
EOF
sudo sysctl --system > /dev/null

# 4. Configure UFW Firewall
echo "🛡️ Configuring Firewall..."
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw --force enable || true

echo "=========================================================="
echo "🎉 Server preparation complete! Ready for n8n deployment."
echo "=========================================================="
