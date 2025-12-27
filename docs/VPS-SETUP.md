# VPS Setup Guide - hagiik.my.id

## Prerequisites

- VPS with Docker & Docker Compose installed
- Domain `hagiik.my.id` DNS pointing to VPS IP
- SSH access to VPS

---

## Step 1: Clone Docker Config

```bash
cd /
git clone https://github.com/YOUR_REPO/docker.git docker
cd /docker
```

---

## Step 2: Setup Environment

```bash
cp .env.example .env
nano .env
```

Fill in:

```env
DB_ROOT_PASSWORD=your_strong_password_here
DB_HAGIIK_PASSWORD=your_hagiik_password_here
SSL_EMAIL=your@email.com
```

---

## Step 3: Clone Laravel Project

```bash
cd /docker/sites
git clone git@github.com:Get-It-Launched/portfolio.git hagiik.my.id
cd hagiik.my.id
cp .env.example .env
nano .env
```

Fill in Laravel .env:

```env
APP_URL=https://hagiik.my.id

DB_CONNECTION=pgsql
DB_HOST=database
DB_PORT=5432
DB_DATABASE=hagiik_db
DB_USERNAME=postgres
DB_PASSWORD=your_strong_password_here

REDIS_HOST=redis
REDIS_PORT=6379
```

---

## Step 4: Create Required Directories

```bash
cd /docker
mkdir -p logs/nginx logs/php/hagiik
mkdir -p certbot/conf certbot/www
mkdir -p nginx/ssl
```

---

## Step 5: Create Self-Signed SSL (Temporary)

```bash
mkdir -p /docker/certbot/conf/live/hagiik.my.id

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /docker/certbot/conf/live/hagiik.my.id/privkey.pem \
    -out /docker/certbot/conf/live/hagiik.my.id/fullchain.pem \
    -subj "/CN=hagiik.my.id"
```

---

## Step 6: Build & Start Docker

```bash
cd /docker
docker compose build --no-cache
docker compose up -d
docker compose ps
```

All containers should be "Up (healthy)".

---

## Step 7: Setup Laravel

```bash
docker compose exec site1 composer install --no-dev --optimize-autoloader
docker compose exec site1 php artisan key:generate
docker compose exec site1 php artisan migrate --force
docker compose exec site1 php artisan storage:link
docker compose exec site1 php artisan config:clear
docker compose exec site1 php artisan cache:clear
docker compose exec site1 php artisan optimize
```

---

## Step 8: Fix Permissions

```bash
docker compose exec site1 chown -R www-data:www-data storage bootstrap/cache
docker compose exec site1 chmod -R 775 storage bootstrap/cache
```

---

## Step 9: Setup Let's Encrypt SSL (Production)

```bash
docker compose run --rm certbot certonly --webroot \
    --webroot-path=/var/www/certbot \
    -d hagiik.my.id -d www.hagiik.my.id \
    --email your@email.com --agree-tos --no-eff-email

docker compose restart nginx
```

---

## Step 10: Test

Open in browser:

```
https://hagiik.my.id
```

---

## Troubleshooting

### Check container status

```bash
docker compose ps
```

### Check nginx logs

```bash
docker compose logs nginx --tail 50
```

### Check Laravel logs

```bash
docker compose exec site1 tail -50 storage/logs/laravel.log
```

### Restart all services

```bash
docker compose restart
```

### Rebuild a service

```bash
docker compose build --no-cache site1
docker compose up -d
```

---

## Update from Git

```bash
cd /docker
git pull origin main
docker compose down
docker compose build --no-cache
docker compose up -d

# Re-run Laravel setup if needed
docker compose exec site1 composer install --no-dev --optimize-autoloader
docker compose exec site1 php artisan migrate --force
docker compose exec site1 php artisan optimize
```
