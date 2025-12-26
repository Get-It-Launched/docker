# Troubleshooting Guide

Panduan untuk menyelesaikan masalah umum pada Docker Laravel setup.

---

## Quick Diagnostic Commands

```bash
# Check container status
docker compose ps

# View all logs
docker compose logs

# View specific container logs
docker compose logs -f site1
docker compose logs -f nginx
docker compose logs -f database

# Check resource usage
docker stats

# Check disk space
df -h

# Check memory
free -m
```

---

## Container Issues

### Problem: Container won't start

**Symptoms:**

- `docker compose ps` menunjukkan status "Exited" atau "Restarting"

**Solution:**

```bash
# Check logs for error
docker compose logs site1

# Common fixes:
# 1. Check if port is in use
sudo lsof -i :80
sudo lsof -i :443

# 2. Rebuild container
docker compose down
docker compose build --no-cache site1 #build untuk 1 site/domain saja
docker compose up -d

# 3. Check disk space
df -h
docker system prune -a  # WARNING: removes unused images
```

### Problem: Container keeps restarting

**Symptoms:**

- Status "Restarting" atau exit code non-zero

**Solution:**

```bash
# Check exit code
docker inspect site1 --format='{{.State.ExitCode}}'

# View last logs before crash
docker compose logs --tail=100 site1

# Common causes:
# - PHP syntax error in code
# - Missing dependencies
# - Wrong permissions
# - Out of memory
```

### Problem: Cannot connect between containers

**Symptoms:**

- "Connection refused" ke database atau redis
- Laravel tidak bisa konek ke `database:5432`

**Solution:**

```bash
# Check if containers are on same network
docker network inspect docker_app-network

# Verify container hostname resolution
docker compose exec site1 ping database
docker compose exec site1 ping redis

# Check database is accepting connections
docker compose exec database pg_isready -U postgres

# Common fixes:
# In .env Laravel, gunakan container name, bukan localhost:
# DB_HOST=database (bukan localhost atau 127.0.0.1)
# REDIS_HOST=redis (bukan localhost)
```

---

## Nginx Issues

### Problem: 502 Bad Gateway

**Symptoms:**

- Browser menampilkan "502 Bad Gateway"
- Nginx tidak bisa konek ke PHP-FPM

**Solution:**

```bash
# Check if PHP-FPM is running
docker compose exec site1 ps aux | grep php-fpm

# Check nginx error log
docker compose logs nginx
tail -f /docker/logs/nginx/error.log

# Verify upstream is correct in nginx config
# Check nginx/nginx.conf - upstream should match container name

# Restart PHP-FPM
docker compose restart site1

# Common causes:
# - PHP-FPM not running
# - Wrong upstream name in nginx config
# - Container network issue
```

### Problem: 504 Gateway Timeout

**Symptoms:**

- Request timeout setelah 60 detik
- Long-running PHP scripts fail

**Solution:**

```bash
# Increase timeouts in nginx config
# Edit nginx/nginx.conf or site config:
fastcgi_read_timeout 300s;
fastcgi_send_timeout 300s;

# Also check php.ini:
max_execution_time = 300

# Reload nginx
docker compose exec nginx nginx -s reload
```

### Problem: SSL Certificate Error

**Symptoms:**

- Browser menampilkan "Your connection is not private"
- Certificate expired atau invalid

**Solution:**

```bash
# Check certificate expiry
docker compose exec nginx openssl x509 -in /etc/letsencrypt/live/test1.com/fullchain.pem -noout -dates

# Renew certificate manually
docker compose run --rm certbot renew --force-renew

# Reload nginx
docker compose exec nginx nginx -s reload

# If certificate doesn't exist, run ssl-init:
./scripts/ssl-init.sh test1.com admin@test1.com
```

### Problem: Nginx config test fails

**Symptoms:**

- `nginx -t` returns error

**Solution:**

```bash
# Test nginx config
docker compose exec nginx nginx -t

# Common errors and fixes:

# Error: "host not found in upstream"
# - Check container name in upstream matches docker-compose.yml
# - Ensure PHP container is running

# Error: "cannot load certificate"
# - SSL certificate file missing
# - Run ssl-init.sh untuk domain tersebut

# Error: "duplicate location"
# - Check for duplicate location blocks
```

---

## Database Issues

### Problem: Connection refused

**Symptoms:**

- `SQLSTATE[08006] Connection refused`
- Laravel tidak bisa konek ke database

**Solution:**

```bash
# Check if database is running
docker compose ps database
docker compose logs database

# Check if database accepts connections
docker compose exec database pg_isready -U postgres

# Verify credentials di .env Laravel
DB_CONNECTION=pgsql
DB_HOST=database       # Container name!
DB_PORT=5432
DB_DATABASE=test1_db
DB_USERNAME=test1_user
DB_PASSWORD=your_password

# Test connection from PHP container
docker compose exec site1 php artisan tinker
>>> DB::connection()->getPdo();

# Common causes:
# - Wrong DB_HOST (harus container name, bukan localhost)
# - Database container belum selesai initialize
# - Wrong credentials
```

### Problem: Database does not exist

**Symptoms:**

- `FATAL: database "test1_db" does not exist`

**Solution:**

```bash
# Check available databases
docker compose exec database psql -U postgres -c '\l'

# Create database manually
docker compose exec database psql -U postgres -c 'CREATE DATABASE test1_db;'

# Or run init script
docker compose down
docker volume rm docker_postgres-data
docker compose up -d database
# Wait for init script to complete
sleep 10
docker compose up -d
```

### Problem: Permission denied on database

**Symptoms:**

- `FATAL: password authentication failed`
- `permission denied for table`

**Solution:**

```bash
# Check user exists
docker compose exec database psql -U postgres -c '\du'

# Reset user password
docker compose exec database psql -U postgres -c "ALTER USER test1_user WITH PASSWORD 'new_password';"

# Grant permissions
docker compose exec database psql -U postgres -d test1_db -c "GRANT ALL ON ALL TABLES IN SCHEMA public TO test1_user;"
docker compose exec database psql -U postgres -d test1_db -c "GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO test1_user;"
```

---

## PHP Issues

### Problem: Out of memory

**Symptoms:**

- `Allowed memory size of X bytes exhausted`
- PHP process killed

**Solution:**

```bash
# Check current limits
docker compose exec site1 php -i | grep memory_limit

# Increase in php/php.ini:
memory_limit = 512M

# Restart container
docker compose restart site1

# For specific script, use ini_set:
ini_set('memory_limit', '512M');

# Or via command line:
docker compose exec site1 php -d memory_limit=512M artisan your:command
```

### Problem: Max execution time exceeded

**Symptoms:**

- `Maximum execution time of 60 seconds exceeded`

**Solution:**

```bash
# For web requests, edit php/php.ini:
max_execution_time = 300

# For CLI commands:
docker compose exec site1 php -d max_execution_time=0 artisan your:long-command

# Restart container
docker compose restart site1
```

### Problem: Class not found

**Symptoms:**

- `Class 'App\Models\User' not found`
- Autoload issues

**Solution:**

```bash
# Dump autoload
docker compose exec site1 composer dump-autoload -o

# Clear cached config
docker compose exec site1 php artisan config:clear
docker compose exec site1 php artisan clear-compiled

# Reinstall dependencies
docker compose exec site1 composer install --no-dev --optimize-autoloader
```

---

## Laravel Issues

### Problem: Artisan command fails

**Symptoms:**

- `Command not found`
- `Class does not exist`

**Solution:**

```bash
# Check you're in correct directory
docker compose exec site1 pwd
# Should be /var/www/html

# Clear all caches
docker compose exec site1 php artisan optimize:clear

# Rebuild autoload
docker compose exec site1 composer dump-autoload -o

# Check command exists
docker compose exec site1 php artisan list
```

### Problem: Session not persisting

**Symptoms:**

- User logged out after page refresh
- Session data hilang

**Solution:**

```bash
# Check Redis connection
docker compose exec site1 php artisan tinker
>>> Cache::store('redis')->put('test', 'value', 60);
>>> Cache::store('redis')->get('test');

# Verify .env session config:
SESSION_DRIVER=redis
REDIS_HOST=redis
REDIS_PORT=6379

# Clear session cache
docker compose exec site1 php artisan cache:clear
```

### Problem: File upload fails

**Symptoms:**

- Image upload error
- `The file failed to upload`

**Solution:**

```bash
# Check php.ini limits:
upload_max_filesize = 50M
post_max_size = 50M
max_file_uploads = 20

# Check nginx limits (nginx.conf):
client_max_body_size 50M;

# Check storage permissions:
docker compose exec site1 ls -la storage/app
docker compose exec site1 chmod -R 775 storage
docker compose exec site1 chown -R www-data:www-data storage

# Verify storage link exists:
docker compose exec site1 php artisan storage:link
```

---

## Performance Issues

### Problem: Slow response time

**Symptoms:**

- Page load > 3 seconds
- High TTFB

**Solution:**

```bash
# Check if caches are enabled
docker compose exec site1 php artisan optimize:status

# Enable all caches
docker compose exec site1 php artisan optimize

# Check OPcache
docker compose exec site1 php -i | grep opcache.enable

# Monitor resource usage
docker stats

# Common issues:
# - Missing route cache
# - Missing config cache
# - OPcache disabled
# - Too many database queries (N+1)
```

### Problem: High memory usage

**Symptoms:**

- Container memory at limit
- OOM kills

**Solution:**

```bash
# Check memory usage
docker stats --no-stream

# Increase memory limit in docker-compose.yml:
deploy:
  resources:
    limits:
      memory: 1024M

# Optimize PHP-FPM workers in php/www.conf:
pm.max_children = 10  # Reduce if needed
pm.max_spare_servers = 3

# Restart containers
docker compose restart site1
```

---

## Logs Location

| Log                 | Location                                           |
| ------------------- | -------------------------------------------------- |
| Nginx access        | `/docker/logs/nginx/access.log`                    |
| Nginx error         | `/docker/logs/nginx/error.log`                     |
| Site-specific nginx | `/docker/logs/nginx/test1.com.access.log`          |
| PHP error           | `/docker/logs/php/site1/error.log`                 |
| Laravel log         | `/docker/sites/test1.com/storage/logs/laravel.log` |
| PostgreSQL          | `docker compose logs database`                     |

**View logs in real-time:**

```bash
# All containers
docker compose logs -f

# Specific container
docker compose logs -f site1

# Nginx access log
tail -f /docker/logs/nginx/access.log

# Laravel log
tail -f /docker/sites/test1.com/storage/logs/laravel.log
```

---

## Emergency Recovery

### Complete restart

```bash
cd /docker
docker compose down
docker compose up -d
```

### Rebuild everything

```bash
cd /docker
docker compose down
docker compose build --no-cache
docker compose up -d
```

### Factory reset (WARNING: loses data!)

```bash
cd /docker
docker compose down -v  # Removes volumes too!
docker system prune -a
docker compose build
docker compose up -d
```
