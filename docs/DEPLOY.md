# Laravel Deployment Guide

Panduan untuk deploy dan update aplikasi Laravel di Docker environment.

---

## Quick Reference

| Task            | Command                                           |
| --------------- | ------------------------------------------------- |
| Full deploy     | `./scripts/deploy.sh site1 full`                  |
| Quick update    | `./scripts/deploy.sh site1 quick`                 |
| View logs       | `docker compose logs -f site1`                    |
| Enter container | `docker compose exec site1 bash`                  |
| Run artisan     | `docker compose exec site1 php artisan <command>` |

---

## Method 1: Using Deploy Script (Recommended)

```bash
cd /docker

# Full deployment (git pull + composer + npm + migrations + cache)
./scripts/deploy.sh site1 full

# Quick deployment (git pull + cache clear only)
./scripts/deploy.sh site1 quick
```

### What the script does:

**Full Mode:**

1. Enable maintenance mode
2. Git pull latest code
3. Composer install (production)
4. NPM build (if package.json exists)
5. Run migrations
6. Optimize & cache config, routes, views
7. Set permissions
8. Disable maintenance mode

**Quick Mode:**

1. Enable maintenance mode
2. Git pull latest code
3. Clear & rebuild cache
4. Set permissions
5. Disable maintenance mode

---

## Method 2: Manual Deployment

### Step 1: Enable Maintenance Mode

```bash
docker compose exec site1 php artisan down --retry=60
```

### Step 2: Pull Latest Code

```bash
cd /docker/sites/test1.com
git pull origin main
```

### Step 3: Install Dependencies

```bash
# Composer (production mode)
docker compose exec site1 composer install --no-dev --optimize-autoloader

# NPM (if needed)
docker compose exec site1 npm ci
docker compose exec site1 npm run build
```

### Step 4: Run Migrations

```bash
docker compose exec site1 php artisan migrate --force
```

### Step 5: Optimize Application

```bash
# Clear all caches
docker compose exec site1 php artisan optimize:clear

# Rebuild caches
docker compose exec site1 php artisan optimize
docker compose exec site1 php artisan view:cache
```

### Step 6: Set Permissions

```bash
docker compose exec site1 chown -R www-data:www-data storage bootstrap/cache
docker compose exec site1 chmod -R 775 storage bootstrap/cache
```

### Step 7: Disable Maintenance Mode

```bash
docker compose exec site1 php artisan up
```

---

## Fresh Installation

Untuk deploy aplikasi Laravel baru:

### Step 1: Clone Repository

```bash
cd /docker/sites
git clone https://github.com/your-org/new-laravel-app.git test1.com
```

### Step 2: Setup Environment

```bash
cd test1.com
cp .env.example .env
nano .env
```

**Konfigurasi `.env` yang penting:**

```env
APP_ENV=production
APP_DEBUG=false
APP_URL=https://test1.com

DB_CONNECTION=pgsql
DB_HOST=database
DB_PORT=5432
DB_DATABASE=test1_db
DB_USERNAME=test1_user
DB_PASSWORD=your_password

CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

REDIS_HOST=redis
REDIS_PORT=6379
```

### Step 3: Restart Container

```bash
cd /docker
docker compose restart site1
```

### Step 4: Setup Application

```bash
# Install dependencies
docker compose exec site1 composer install --no-dev --optimize-autoloader

# Generate app key
docker compose exec site1 php artisan key:generate

# Create storage link
docker compose exec site1 php artisan storage:link

# Run migrations
docker compose exec site1 php artisan migrate --force

# Seed database (if needed)
docker compose exec site1 php artisan db:seed --force

# Optimize
docker compose exec site1 php artisan optimize
```

---

## Migrating Existing Laravel App

Untuk memindahkan aplikasi Laravel yang sudah ada:

### Step 1: Export Database from Old Server

```bash
# On old server
pg_dump -U postgres -d old_database > backup.sql

# Or for MySQL
mysqldump -u root -p old_database > backup.sql
```

### Step 2: Copy Application Files

```bash
# From local machine
scp -r ./your-laravel-app/* user@vps:/docker/sites/test1.com/
```

### Step 3: Import Database

```bash
# Copy backup to container
docker cp backup.sql postgres-db:/tmp/

# Import
docker compose exec database psql -U postgres -d test1_db -f /tmp/backup.sql
```

### Step 4: Update Environment & Permissions

```bash
# Update .env
nano /docker/sites/test1.com/.env

# Reinstall dependencies
docker compose exec site1 composer install --no-dev --optimize-autoloader

# Set permissions
docker compose exec site1 chown -R www-data:www-data storage bootstrap/cache
docker compose exec site1 chmod -R 775 storage bootstrap/cache

# Clear old caches
docker compose exec site1 php artisan optimize:clear
docker compose exec site1 php artisan optimize
```

---

## Common Artisan Commands

```bash
# Cache commands
docker compose exec site1 php artisan config:cache
docker compose exec site1 php artisan route:cache
docker compose exec site1 php artisan view:cache
docker compose exec site1 php artisan optimize

# Clear commands
docker compose exec site1 php artisan config:clear
docker compose exec site1 php artisan route:clear
docker compose exec site1 php artisan view:clear
docker compose exec site1 php artisan cache:clear
docker compose exec site1 php artisan optimize:clear

# Database
docker compose exec site1 php artisan migrate --force
docker compose exec site1 php artisan migrate:status
docker compose exec site1 php artisan db:seed --force

# Queue (if using)
docker compose exec site1 php artisan queue:work --stop-when-empty

# Maintenance
docker compose exec site1 php artisan down
docker compose exec site1 php artisan up

# Debugging
docker compose exec site1 php artisan tinker
```

---

## Rollback Deployment

Jika terjadi masalah setelah deploy:

### Option 1: Git Rollback

```bash
cd /docker/sites/test1.com

# Enable maintenance
docker compose exec site1 php artisan down

# Rollback to previous commit
git revert HEAD

# Atau reset ke commit tertentu
git reset --hard <commit-hash>

# Reinstall dependencies
docker compose exec site1 composer install --no-dev --optimize-autoloader

# Rollback migrations (hati-hati, bisa kehilangan data!)
docker compose exec site1 php artisan migrate:rollback

# Clear cache
docker compose exec site1 php artisan optimize:clear
docker compose exec site1 php artisan optimize

# Disable maintenance
docker compose exec site1 php artisan up
```

### Option 2: Database Restore

```bash
# Restore from backup
./scripts/restore-db.sh test1_db /docker/backups/database/test1_db_20231226_020000.sql.gz
```

---

## Zero-Downtime Deployment Tips

1. **Selalu gunakan maintenance mode** untuk mencegah error saat deploy

2. **Backup database sebelum deploy**:

   ```bash
   ./scripts/backup-db.sh test1_db
   ```

3. **Test migrations di staging dulu** sebelum production

4. **Monitor logs setelah deploy**:

   ```bash
   docker compose logs -f site1
   ```

5. **Rollback plan**: Selalu siapkan cara rollback sebelum deploy

---

## Troubleshooting Deployment

### Error: Permission denied

```bash
docker compose exec site1 chown -R www-data:www-data storage bootstrap/cache
docker compose exec site1 chmod -R 775 storage bootstrap/cache
```

### Error: Class not found

```bash
docker compose exec site1 composer dump-autoload -o
```

### Error: Migration failed

```bash
# Check migration status
docker compose exec site1 php artisan migrate:status

# Rollback last migration
docker compose exec site1 php artisan migrate:rollback --step=1

# Fix dan retry
docker compose exec site1 php artisan migrate --force
```

### Error: Cache issues

```bash
docker compose exec site1 php artisan optimize:clear
docker compose exec site1 php artisan config:clear
docker compose exec site1 php artisan cache:clear
```
