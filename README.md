# Docker Setup for 4 Laravel Websites

Setup production-ready Docker environment untuk hosting 4 Laravel websites di VPS Ubuntu.

## Features

- 🐳 Docker + Docker Compose
- 🌐 Nginx reverse proxy dengan SSL (Let's Encrypt)
- 🐘 PostgreSQL 16 dengan database terpisah per site
- 🔴 Redis untuk session & cache
- 🔒 Security hardening (UFW, rate limiting, security headers)
- 📦 PHP 8.3 FPM dengan OPcache JIT
- 🔄 Auto SSL renewal
- 📊 Centralized logging

## Quick Start

```bash
# 1. Clone repository
git clone <this-repo> /docker
cd /docker

# 2. Copy environment file
cp .env.example .env
nano .env  # Edit with your values

# 3. Build and start
docker compose build
docker compose up -d

# 4. Setup SSL (after DNS is configured)
./scripts/ssl-init.sh test1.com admin@test1.com
```

## Architecture

```
                    Internet
                       │
                 ┌─────┴─────┐
                 │   Nginx   │ :80, :443
                 └─────┬─────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
   ┌────┴────┐   ┌────┴────┐   ┌────┴────┐
   │  Site1  │   │  Site2  │   │  Site3  │ ...
   │ PHP-FPM │   │ PHP-FPM │   │ PHP-FPM │
   └────┬────┘   └────┬────┘   └────┬────┘
        │              │              │
        └──────────────┼──────────────┘
                       │
              ┌────────┴────────┐
              │                 │
         ┌────┴────┐       ┌───┴───┐
         │PostgreSQL│       │ Redis │
         └─────────┘       └───────┘
```

## Directory Structure

```
/docker/
├── docker-compose.yml      # Main orchestrator
├── .env                    # Environment variables
├── nginx/                  # Nginx configuration
├── php/                    # PHP-FPM configuration
├── sites/                  # Laravel applications
├── database/               # Database init scripts
├── certbot/                # SSL certificates
├── logs/                   # Centralized logs
├── scripts/                # Helper scripts
└── docs/                   # Documentation
```

## Documentation

- [📖 Initial Setup Guide](docs/SETUP.md)
- [🚀 Deployment Guide](docs/DEPLOY.md)
- [🔧 Troubleshooting](docs/TROUBLESHOOT.md)

## Requirements

- VPS with Ubuntu 22.04/24.04 LTS
- Minimum 8GB RAM
- Docker & Docker Compose
- Domain names pointing to VPS IP

## Scripts

| Script                 | Purpose                    |
| ---------------------- | -------------------------- |
| `scripts/deploy.sh`    | Deploy/update Laravel apps |
| `scripts/ssl-init.sh`  | Initial SSL setup          |
| `scripts/ssl-renew.sh` | SSL renewal (cron)         |
| `scripts/backup-db.sh` | Database backup            |

## Common Commands

```bash
# Start all containers
docker compose up -d

# Stop all containers
docker compose down

# View logs
docker compose logs -f

# Enter PHP container
docker compose exec site1 bash

# Run artisan command
docker compose exec site1 php artisan migrate
```

## License

MIT
