# n8n on AWS EC2 & Docker (High-Scale Production)

Deploy the powerful workflow automation platform [n8n](https://n8n.io) to AWS EC2 using Docker Compose, Queue Mode, PostgreSQL 16, Redis BullMQ, and Nginx reverse proxy. Built for 99.9% uptime and zero-downtime rolling updates.

---

## 🏛️ Architecture Overview

```
                 Incoming Traffic (Cloudflare / Web)
                                │
                                ▼
                       Nginx Reverse Proxy
                         (Port 80 / 443)
                         /             \
      UI & WebSocket    /               \  /webhook/*
                       ▼                 ▼
                   n8n-main         n8n-webhook
               (UI & Scheduler)  (High Throughput Ingest)
                       \                 /
                        ▼               ▼
                        Redis (BullMQ Queue)
                                │
                                ▼
                        n8n-worker Cluster
                       (Scalable 1, 2, 4+)
                                │
                                ▼
                        PostgreSQL 16 DB
```

---

## ⚡ Deployment Highlights

- 🔄 **Queue Mode Execution:** UI, Webhooks, and Workers are completely decoupled.
- ⚡ **Dedicated Webhook Handler:** Independent high-throughput worker for `/webhook/*` endpoints.
- 📈 **Horizontal Worker Scaling:** Add or remove background workers anytime with zero downtime.
- 🛡️ **Zero-Downtime Deployment:** Rolling container restarts with automated health check verification.
- 💾 **Automated Backups:** Daily compressed PostgreSQL dumps with 14-day auto-retention cleanup.

---

## ⚙️ Configuration (`.env`)

Copy `.env.example` to `.env` and fill in your values:

```bash
DOMAIN_NAME=n8n.yourdomain.com
N8N_ADMIN_EMAIL=admin@yourdomain.com
N8N_ADMIN_PASSWORD=your_secure_password
N8N_ENCRYPTION_KEY=your_encryption_key_here
POSTGRES_PASSWORD=your_postgres_password_here
REDIS_PASSWORD=your_redis_password_here
```

---

## 🚀 Deployment Methods

### Option 1: Remote One-Command Deploy (From Local Machine)

Deploy directly to your EC2 instance using your `.pem` key:

```bash
./remote-deploy.sh <EC2_PUBLIC_IP> ubuntu ./n8n-server-key.pem
```

This will automatically:
1. Connect via SSH.
2. Initialize Docker, Compose, and 3GB Swap space on the VPS (if not installed).
3. Sync repository configuration.
4. Launch n8n in high-scale Queue Mode.

---

### Option 2: Direct on AWS Server

```bash
# 1. Clone the repository
git clone https://github.com/developer-sujon/n8n.git n8n-server
cd n8n-server

# 2. Configure environment
cp .env.example .env
nano .env

# 3. Initialize server environment (Docker, Firewall, Swap)
./setup-server.sh

# 4. Deploy n8n cluster
./deploy.sh
```

---

## 📈 Worker Scaling

Scale background worker processes dynamically based on workload:

```bash
# Scale to 4 workers
./scale.sh 4

# Scale back to 2 workers
./scale.sh 2
```

---

## 💾 Database Backups

```bash
# Create manual compressed backup
./backup.sh

# Backups are saved to ./backups/n8n_backup_YYYYMMDD_HHMMSS.sql.gz
```

---

## 🌐 Domain & SSL Setup

1. In Cloudflare or your DNS provider, create an **A Record**:
   - **Name:** `n8n` (or your chosen subdomain)
   - **IPv4 Address:** `<YOUR_EC2_PUBLIC_IP>`
   - **Proxy status:** Proxied (Orange Cloud) for instant SSL, or DNS only.
2. Visit `https://your-domain.com` in your browser.
3. Log in with your admin credentials configured in `.env`.

---

## What is n8n?

n8n is a **fair-code licensed workflow automation platform** — a self-hosted, scalable alternative to Zapier and Make.

- 🔌 400+ built-in node integrations
- 🎨 Visual canvas workflow builder
- 🤖 Advanced AI Agent workflows with LangChain
- 🔐 Self-hosted on your own AWS infrastructure — complete data ownership
