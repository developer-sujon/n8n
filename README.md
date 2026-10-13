# High-Scale n8n Production Server

Production-ready, horizontally scalable n8n deployment with **Queue Mode**, PostgreSQL 16, Redis BullMQ, dedicated webhook handlers, and Nginx reverse proxy. Built for 99.9% uptime and zero-downtime rolling updates.

---

## 🏛️ Architecture Overview

```
                               ┌────────────────────────────────┐
                               │     Incoming Webhooks & UI     │
                               │   (Cloudflare / Public Web)    │
                               └───────────────┬────────────────┘
                                               │ Port 80 / 443
                                               ▼
                              ┌──────────────────────────────────┐
                              │     Nginx Reverse Proxy & LB     │
                              │           (n8n-proxy)            │
                              └────────┬─────────────────┬───────┘
                                       │                 │
                /rest/push & UI & API  │                 │ /webhook/*
                                       ▼                 ▼
                        ┌──────────────────┐  ┌──────────────────┐
                        │     n8n-main     │  │   n8n-webhook    │
                        │ (UI & Scheduler) │  │  (Event Ingest)  │
                        └────────┬─────────┘  └────────┬─────────┘
                                 │                     │
                    Dispatches   │                     │ Dispatches
                    Jobs         ▼                     ▼ Jobs
                        ┌────────────────────────────────────────┐
                        │             Redis (BullMQ)             │
                        └──────────────────┬─────────────────────┘
                                           │ Pulls Tasks
                                           ▼
                        ┌────────────────────────────────────────┐
                        │        n8n-worker Cluster              │
                        │   (Scalable: 1, 2, 4, 8+ instances)    │
                        └──────────────────┬─────────────────────┘
                                           │
                                           │ Reads / Writes
                                           ▼
                        ┌────────────────────────────────────────┐
                        │          PostgreSQL 16 DB              │
                        │    (Workflows, Executions, State)      │
                        └────────────────────────────────────────┘
```

---

## 🚀 Key Features

1. **Queue Mode Execution (`EXECUTIONS_MODE=queue`)**:
   - Webhook reception and workflow executions are decoupled. Heavy workflows run asynchronously in background workers, preventing UI freeze and webhook timeouts.
2. **Dedicated Webhook Node (`n8n-webhook`)**:
   - Directs all `/webhook/` traffic to an isolated high-throughput webhook daemon.
3. **Horizontal Worker Scaling**:
   - Dynamically scale worker nodes anytime via `./scale.sh <number_of_workers>`.
4. **Zero-Downtime Deployment (`deploy.sh`)**:
   - Rolling updates with automated health checking against `/healthz` before traffic handoff.
5. **Disk Protection & Auto-Pruning**:
   - Execution data automatically pruned after 7 days (`EXECUTIONS_DATA_PRUNE=true`) to prevent database bloat.
6. **Automated Backups (`backup.sh`)**:
   - One-command compressed PostgreSQL database dumps with 14-day retention cleanup.

---

## ⚙️ Environment Variables (`.env`)

Only **4 essential variables** are required:

| Variable | Description |
|---|---|
| `DOMAIN_NAME` | Your n8n public domain or IP (e.g. `n8n.yourdomain.com`) |
| `N8N_ENCRYPTION_KEY` | Master encryption key for n8n credentials |
| `POSTGRES_PASSWORD` | PostgreSQL database root password |
| `REDIS_PASSWORD` | Redis queue authentication password |

---

## 🛠️ Deployment Instructions

### Option A: Local / Direct VPS Execution

```bash
# 1. Clone repository to server
git clone <your-repo-url> n8n-server
cd n8n-server

# 2. Configure environment
cp .env.example .env
nano .env

# 3. Initial server setup (Installs Docker, Compose, and Firewall)
./setup-server.sh

# 4. Deploy n8n cluster
./deploy.sh
```

### Option B: Remote One-Command Deployment (Using SSH Key)

From your local machine:
```bash
./remote-deploy.sh <SERVER_IP> ubuntu ./n8n-server-key.pem
```

---

## 📈 Worker Scaling

Scale background workers dynamically without downtime:

```bash
# Scale to 4 workers
./scale.sh 4

# Scale back to 2 workers
./scale.sh 2
```

---

## 💾 Backups & Disaster Recovery

```bash
# Take manual database backup
./backup.sh

# Backups are stored in ./backups/n8n_backup_YYYYMMDD_HHMMSS.sql.gz
```

---

## 📡 Health & Monitoring

| Endpoint | Description |
|---|---|
| `GET /health` | Public HTTP health check probe for load balancers |
| `GET /healthz` | n8n internal readiness probe |
