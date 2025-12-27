# Panduan Menambah Domain & SSL Baru

Dokumentasi step-by-step untuk menambahkan site Laravel baru ke Docker VPS.

## 📋 Checklist

- [ ] Konfigurasi Docker (docker-compose.yml)
- [ ] Konfigurasi Nginx (nginx.conf + site config)
- [ ] Update deploy script
- [ ] Clone Laravel project
- [ ] Setup database
- [ ] Setup DNS
- [ ] Request SSL certificate

---

## 1️⃣ Konfigurasi Docker

### Edit `docker-compose.yml`

Tambahkan volume nginx untuk site baru:
```yaml
nginx:
  volumes:
    # ... existing volumes ...
    - ./sites/DOMAIN.COM/public:/var/www/DOMAIN.COM/public:ro
  depends_on:
    # ... existing ...
    - DOMAIN_COM  # underscore, bukan titik
```

Tambahkan service container baru:
```yaml
  # ---------------------------------------------------------------------------
  # DOMAIN.COM (Laravel PHP-FPM)
  # ---------------------------------------------------------------------------
  DOMAIN_COM:
    build:
      context: ./php
      dockerfile: Dockerfile
    container_name: laravel-DOMAIN
    restart: unless-stopped
    working_dir: /var/www/html
    volumes:
      - ./sites/DOMAIN.COM:/var/www/html
      - ./php/php.ini:/usr/local/etc/php/php.ini:ro
      - ./php/www.conf:/usr/local/etc/php-fpm.d/www.conf:ro
      - ./logs/php/DOMAIN:/var/log/php
    environment:
      - APP_ENV=production
      - APP_DEBUG=false
      - PHP_MEMORY_LIMIT=256M
      - PHP_MAX_EXECUTION_TIME=60
    networks:
      - app-network
    depends_on:
      database:
        condition: service_healthy
      redis:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: 512M
```

**Catatan**: Ganti `DOMAIN.COM` dengan domain Anda (misal: `example.com`) dan `DOMAIN_COM` dengan versi underscore (misal: `example_com`).

---

## 2️⃣ Konfigurasi Nginx

### Edit `nginx/nginx.conf`

Tambahkan upstream backend:
```nginx
    # DOMAIN.COM
    upstream DOMAIN_COM_backend {
        server DOMAIN_COM:9000;
        keepalive 16;
    }
```

### Buat file site config baru

Copy dari template dan edit:
```bash
cp nginx/sites-enabled/wedlistfy.com.conf nginx/sites-enabled/DOMAIN.COM.conf
```

Edit file baru, ganti semua:
- `wedlistfy.com` → `DOMAIN.COM`
- `wedlistfy_com_backend` → `DOMAIN_COM_backend`
- Path sesuaikan

---

## 3️⃣ Update Deploy Script

Edit `scripts/deploy.sh`:

```bash
# Di bagian show_usage():
echo "Sites: hagiik.my.id, wedlistfy.com, DOMAIN.COM"

# Di bagian validate site:
case $SITE in
    hagiik.my.id|wedlistfy.com|DOMAIN.COM)
    ;;

# Di bagian map site:
case $SITE in
    hagiik.my.id) DOMAIN="hagiik.my.id"; CONTAINER="hagiik_my_id" ;;
    wedlistfy.com) DOMAIN="wedlistfy.com"; CONTAINER="wedlistfy_com" ;;
    DOMAIN.COM) DOMAIN="DOMAIN.COM"; CONTAINER="DOMAIN_COM" ;;
esac
```

---

## 4️⃣ Commit & Push ke GitHub

```bash
# Di komputer lokal
cd /path/to/docker
git add .
git commit -m "Add DOMAIN.COM site configuration"
git push origin main
```

---

## 5️⃣ Deploy di VPS

### Pull konfigurasi terbaru
```bash
cd /docker
git pull origin main
```

### Clone Laravel project
```bash
cd /docker/sites
git clone git@github.com:USERNAME/REPO.git DOMAIN.COM
```

### Setup Laravel .env
```bash
cd /docker/sites/DOMAIN.COM
cp .env.example .env
nano .env
```

Update nilai:
```
APP_URL=https://DOMAIN.COM

DB_CONNECTION=pgsql
DB_HOST=database
DB_PORT=5432
DB_DATABASE=DOMAIN_db
DB_USERNAME=DOMAIN_user
DB_PASSWORD=SECURE_PASSWORD

REDIS_HOST=redis
CACHE_DRIVER=redis
SESSION_DRIVER=redis
```

### Rebuild containers
```bash
cd /docker
docker compose down
docker compose up -d --build
```

### Buat database
```bash
docker compose exec database psql -U postgres
```

```sql
CREATE DATABASE DOMAIN_db;
CREATE USER DOMAIN_user WITH PASSWORD 'SECURE_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE DOMAIN_db TO DOMAIN_user;
\c DOMAIN_db
GRANT ALL ON SCHEMA public TO DOMAIN_user;
\q
```

### Install Laravel dependencies
```bash
docker compose exec DOMAIN_COM composer install --no-dev --optimize-autoloader
docker compose exec DOMAIN_COM php artisan key:generate
docker compose exec DOMAIN_COM php artisan storage:link
docker compose exec DOMAIN_COM php artisan migrate --force
docker compose exec DOMAIN_COM php artisan optimize
```

### Set permissions
```bash
docker compose exec DOMAIN_COM chown -R www-data:www-data storage bootstrap/cache
docker compose exec DOMAIN_COM chmod -R 775 storage bootstrap/cache
```

---

## 6️⃣ Setup DNS

Di panel DNS registrar domain, tambahkan:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | @ | IP_VPS | 300 |
| A | www | IP_VPS | 300 |

**Cek IP VPS:**
```bash
curl -4 ifconfig.me
```

**Tunggu propagasi DNS (5-30 menit)**

Verifikasi:
```bash
dig A DOMAIN.COM +short
dig A www.DOMAIN.COM +short
```

---

## 7️⃣ Request SSL Certificate

### Buat self-signed temporary (agar nginx bisa start)
```bash
mkdir -p /docker/certbot/conf/live/DOMAIN.COM
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /docker/certbot/conf/live/DOMAIN.COM/privkey.pem \
    -out /docker/certbot/conf/live/DOMAIN.COM/fullchain.pem \
    -subj "/CN=DOMAIN.COM"
```

### Request Let's Encrypt certificate
```bash
cd /docker

# Hapus self-signed
rm -rf /docker/certbot/conf/live/DOMAIN.COM
rm -rf /docker/certbot/conf/archive/DOMAIN.COM
rm -f /docker/certbot/conf/renewal/DOMAIN.COM.conf

# Request certificate dengan DNS challenge
docker run --rm -it -v /docker/certbot/conf:/etc/letsencrypt certbot/certbot certonly \
    --manual \
    --preferred-challenges dns \
    -d DOMAIN.COM \
    -d www.DOMAIN.COM \
    --email YOUR_EMAIL@gmail.com \
    --agree-tos \
    --no-eff-email
```

### ⚠️ PENTING: Saat muncul TXT values

1. **JANGAN langsung Enter**
2. Buka DNS panel domain
3. Tambah TXT record:
   - Name: `_acme-challenge` (TANPA `.DOMAIN.COM`)
   - Value: (copy dari terminal)
4. Tambah TXT record kedua:
   - Name: `_acme-challenge.www` (TANPA `.DOMAIN.COM`)
   - Value: (copy dari terminal)
5. **Tunggu 2-3 menit**
6. Verifikasi di: https://toolbox.googleapps.com/apps/dig/#TXT/_acme-challenge.DOMAIN.COM
7. Jika sudah muncul → **Baru tekan Enter**

### Restart nginx
```bash
docker compose restart nginx
```

### Verifikasi SSL
```bash
curl -vI https://DOMAIN.COM 2>&1 | grep -A5 "Server certificate"
```

---

## 🔄 Renewal SSL

SSL Let's Encrypt berlaku 90 hari. Untuk renew:

```bash
docker run --rm -it -v /docker/certbot/conf:/etc/letsencrypt certbot/certbot certonly \
    --manual \
    --preferred-challenges dns \
    -d DOMAIN.COM \
    -d www.DOMAIN.COM \
    --email YOUR_EMAIL@gmail.com \
    --agree-tos \
    --no-eff-email
```

Ikuti langkah TXT record seperti di atas, lalu:
```bash
docker compose restart nginx
```

---

## 🛠 Troubleshooting

### Nginx tidak mau start
```bash
# Cek error
docker compose logs nginx --tail=20

# Test konfigurasi
docker compose exec nginx nginx -t
```

### SSL Certificate error
```bash
# Cek certificate ada
ls -la /docker/certbot/conf/live/DOMAIN.COM/

# Cek certificate valid
openssl x509 -in /docker/certbot/conf/live/DOMAIN.COM/fullchain.pem -text -noout | head -20
```

### DNS tidak propagate
```bash
# Cek dengan Google DNS
dig A DOMAIN.COM @8.8.8.8 +short
dig TXT _acme-challenge.DOMAIN.COM @8.8.8.8 +short
```

### Container tidak running
```bash
docker compose ps
docker compose logs DOMAIN_COM --tail=50
```

---

## 📝 Template Checklist

```
Domain: _______________
IP VPS: _______________

[ ] docker-compose.yml updated
[ ] nginx.conf upstream added
[ ] nginx site config created
[ ] deploy.sh updated
[ ] Git commit & push
[ ] VPS git pull
[ ] Laravel cloned
[ ] .env configured
[ ] Docker rebuilt
[ ] Database created
[ ] Laravel dependencies installed
[ ] DNS A records set
[ ] DNS propagated
[ ] SSL certificate obtained
[ ] HTTPS working
```
