# Docker Setup for Laravel Websites

> ⚠️ **PENTING**: Baca [SAFETY-GUIDELINES.md](docs/SAFETY-GUIDELINES.md) sebelum melakukan maintenance!

Setup production-ready Docker environment untuk hosting Laravel websites di VPS Ubuntu.

## 🌐 Websites & Services

| Service                      | Domain                      | Container           |
| ---------------------------- | --------------------------- | ------------------- |
| **Launchify** (Laravel)      | `launchify.co.id`           | `laravel-launchify` |
| **Wedlistfy** (Laravel)      | `wedlistfy.com`             | `laravel-wedlistfy` |
| **Portainer** (Docker UI)    | `portainer.launchify.co.id` | `portainer`         |
| **Uptime Kuma** (Monitoring) | `uptime.launchify.co.id`    | `uptime-kuma`       |

## 📚 Dokumentasi

| Dokumen                                           | Deskripsi                                |
| ------------------------------------------------- | ---------------------------------------- |
| [SAFETY-GUIDELINES.md](docs/SAFETY-GUIDELINES.md) | ⚠️ **WAJIB BACA** - Aturan keamanan data |
| [SETUP.md](docs/SETUP.md)                         | Panduan setup VPS dari awal              |
| [DEPLOY.md](docs/DEPLOY.md)                       | Panduan deployment Laravel               |
| [ADD-NEW-DOMAIN.md](docs/ADD-NEW-DOMAIN.md)       | Panduan menambah domain baru             |
| [TROUBLESHOOT.md](docs/TROUBLESHOOT.md)           | Panduan troubleshooting                  |

## ✨ Features

- 🐳 Docker + Docker Compose v2
- 🌐 Nginx reverse proxy dengan SSL (Let's Encrypt)
- 🐘 PostgreSQL 16 Alpine
- 🔴 Redis 7 untuk session & cache
- 🔒 Security hardening (UFW, rate limiting, security headers)
- 📦 PHP 8.3 FPM dengan OPcache JIT
- 🔄 Auto SSL renewal via Certbot
- 📊 Centralized logging
- 🖥️ Portainer untuk Docker management
- 📈 Uptime Kuma untuk monitoring

## 🚀 Quick Start

```bash
# 1. Clone repository
git clone <this-repo> /docker
cd /docker

# 2. Copy environment file
cp .env.example .env
nano .env  # Edit with your values

# 3. Generate self-signed cert (untuk default server)
mkdir -p nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout nginx/ssl/default.key \
    -out nginx/ssl/default.crt \
    -subj "/CN=localhost"

# 4. Build and start
docker compose build
docker compose up -d

# 5. Setup SSL (after DNS is configured)
./scripts/ssl-init.sh launchify.co.id hello@launchify.co.id
```

## 🏗️ Architecture

```
                      Internet
                         │
                   ┌─────┴─────┐
                   │   Nginx   │ :80, :443
                   │  Reverse  │
                   │   Proxy   │
                   └─────┬─────┘
                         │
      ┌──────────────────┼──────────────────┐
      │                  │                  │
┌─────┴─────┐     ┌─────┴─────┐     ┌──────┴──────┐
│ Launchify │     │ Wedlistfy │     │  Subdomains │
│  PHP-FPM  │     │  PHP-FPM  │     │  Portainer  │
│  :9000    │     │  :9000    │     │ Uptime Kuma │
└─────┬─────┘     └─────┬─────┘     └──────┬──────┘
      │                 │                  │
      └─────────────────┼──────────────────┘
                        │
               ┌────────┴────────┐
               │                 │
          ┌────┴─────┐      ┌───┴───┐
          │PostgreSQL│      │ Redis │
          │   :5432  │      │ :6379 │
          └──────────┘      └───────┘
```

## 📁 Directory Structure

```
/docker/
├── docker-compose.yml      # Main orchestrator
├── .env                    # Environment variables (create from .env.example)
├── nginx/                  # Nginx configuration
│   ├── nginx.conf          # Main nginx config
│   ├── sites-enabled/      # Site configurations
│   │   ├── launchify.co.id.conf
│   │   ├── wedlistfy.com.conf
│   │   ├── portainer.launchify.co.id.conf
│   │   └── uptime.launchify.co.id.conf
│   ├── snippets/           # Reusable config snippets
│   └── ssl/                # Self-signed certs for default server
├── php/                    # PHP-FPM configuration
│   ├── Dockerfile
│   ├── php.ini
│   └── www.conf
├── sites/                  # Laravel applications
│   ├── launchify.co.id/
│   └── wedlistfy.com/
├── database/               # Database init scripts
│   └── init/
├── certbot/                # SSL certificates (Let's Encrypt)
│   ├── conf/
│   └── www/
├── backups/                # Database backups
│   └── database/
├── logs/                   # Centralized logs
│   ├── nginx/
│   └── php/
├── scripts/                # Helper scripts
│   ├── deploy.sh
│   ├── ssl-init.sh
│   ├── ssl-renew.sh
│   └── backup-db.sh
└── docs/                   # Documentation
```

## 🐳 Container Management

### Start/Stop Semua Container

```bash
# Start semua
docker compose up -d

# Stop semua (data tetap aman)
docker compose down

# Restart semua
docker compose restart

# Lihat status
docker compose ps

# Lihat logs semua container
docker compose logs -f
```

### Manage Container Individual

```bash
# Stop satu container
docker compose stop wedlistfy_com

# Start satu container
docker compose start wedlistfy_com

# Restart satu container
docker compose restart wedlistfy_com

# Lihat logs satu container
docker compose logs -f launchify_co_id
```

### Nginx Commands

```bash
# Restart nginx
docker compose restart nginx

# Reload config tanpa downtime
docker compose exec nginx nginx -s reload

# Test konfigurasi nginx
docker compose exec nginx nginx -t
```

## 🔐 SSL Certificate Management

### Request SSL Baru (Manual DNS Challenge)

```bash
# Untuk domain utama
docker run --rm -it -v /docker/certbot/conf:/etc/letsencrypt certbot/certbot certonly \
    --manual \
    --preferred-challenges dns \
    -d launchify.co.id \
    --email hello@launchify.co.id \
    --agree-tos \
    --no-eff-email

# Untuk subdomain
docker run --rm -it -v /docker/certbot/conf:/etc/letsencrypt certbot/certbot certonly \
    --manual \
    --preferred-challenges dns \
    -d portainer.launchify.co.id \
    --email hello@launchify.co.id \
    --agree-tos \
    --no-eff-email
```

### Setelah SSL Berhasil

```bash
docker compose restart nginx
```

## 🚀 Laravel Deployment

```bash
# Enter container
docker compose exec launchify_co_id bash

# Atau jalankan artisan langsung
docker compose exec launchify_co_id php artisan migrate --force
docker compose exec launchify_co_id php artisan optimize
docker compose exec launchify_co_id php artisan queue:restart
```

## 💾 Database Backup

```bash
# Backup semua database
./scripts/backup-db.sh

# Backup database tertentu
./scripts/backup-db.sh launchify_db

# Lihat backup yang ada
ls -la /docker/backups/database/
```

## 📜 Scripts

| Script                 | Purpose                    |
| ---------------------- | -------------------------- |
| `scripts/deploy.sh`    | Deploy/update Laravel apps |
| `scripts/ssl-init.sh`  | Initial SSL setup          |
| `scripts/ssl-renew.sh` | SSL renewal (cron)         |
| `scripts/backup-db.sh` | Database backup            |

## 🔧 Common Commands Reference

```bash
# === Container Management ===
docker compose ps                          # Lihat status
docker compose up -d                       # Start semua
docker compose down                        # Stop semua
docker compose restart nginx               # Restart nginx
docker compose stop wedlistfy_com          # Stop satu service
docker compose start wedlistfy_com         # Start satu service

# === Laravel/PHP ===
docker compose exec launchify_co_id bash                    # Masuk container
docker compose exec launchify_co_id php artisan migrate     # Run migration
docker compose exec launchify_co_id php artisan optimize    # Optimize
docker compose exec launchify_co_id composer install        # Install deps

# === Database ===
docker compose exec database psql -U postgres               # Masuk PostgreSQL
./scripts/backup-db.sh                                      # Backup database

# === Logs ===
docker compose logs -f                     # Semua logs
docker compose logs -f nginx               # Nginx logs saja
docker compose logs -f launchify_co_id     # Laravel logs saja

# === SSL ===
docker compose exec nginx nginx -t         # Test nginx config
docker compose restart nginx               # Reload SSL
```

## 🖥️ VPS Specifications

- **CPU**: 2 vCPU
- **RAM**: 8GB
- **Storage**: 100GB NVMe
- **OS**: Ubuntu 22.04/24.04 LTS
- **IP**: `72.61.215.75`

## 📊 Resource Limits

| Container           | Memory Limit |
| ------------------- | ------------ |
| Nginx               | -            |
| Launchify (PHP-FPM) | 1GB          |
| Wedlistfy (PHP-FPM) | 512MB        |
| PostgreSQL          | 1.5GB        |
| Redis               | 256MB        |
| Portainer           | 128MB        |
| Uptime Kuma         | 256MB        |

## License

MIT
