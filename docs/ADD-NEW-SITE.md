# Panduan Menambah Site/Domain Baru

Panduan langkah demi langkah untuk menambahkan website Laravel baru ke setup Docker.

---

## 📋 Contoh Skenario

Misalkan Anda ingin menambahkan domain baru: `tokoku.com`

---

## 🔧 Langkah-Langkah

### Step 1: Tambah Upstream di nginx.conf

Edit `nginx/nginx.conf`, cari bagian upstream dan tambahkan:

```nginx
# -------------------------------------------------------------------------
# Upstream Definitions (PHP-FPM backends)
# -------------------------------------------------------------------------
# hagiik.my.id
upstream site1_backend {
    server site1:9000;
    keepalive 16;
}

# tokoku.com (BARU)
upstream site2_backend {
    server site2:9000;
    keepalive 16;
}
```

### Step 2: Buat File Nginx Config Baru

Copy file existing dan rename:

```bash
cp nginx/sites-enabled/hagiik.my.id.conf nginx/sites-enabled/tokoku.com.conf
```

Edit `nginx/sites-enabled/tokoku.com.conf`:

```nginx
# Ganti semua:
# - hagiik.my.id → tokoku.com
# - site1_backend → site2_backend

server_name tokoku.com www.tokoku.com;
ssl_certificate /etc/letsencrypt/live/tokoku.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/tokoku.com/privkey.pem;
root /var/www/tokoku.com/public;
access_log /var/log/nginx/tokoku.com.access.log main;
error_log /var/log/nginx/tokoku.com.error.log warn;
fastcgi_pass site2_backend;  # <-- Ganti ini!
```

### Step 3: Tambah Service di docker-compose.yml

Edit `docker-compose.yml`:

```yaml
services:
  nginx:
    volumes:
      # Tambahkan volume untuk site baru
      - ./sites/tokoku.com/public:/var/www/tokoku.com/public:ro
    depends_on:
      - site1
      - site2 # Tambah dependency

  # Site 1 (existing)
  site1:
    # ... (tidak berubah)

  # Site 2 - tokoku.com (BARU)
  site2:
    build:
      context: ./php
      dockerfile: Dockerfile
    container_name: laravel-tokoku
    restart: unless-stopped
    working_dir: /var/www/html
    volumes:
      - ./sites/tokoku.com:/var/www/html
      - ./php/php.ini:/usr/local/etc/php/php.ini:ro
      - ./php/www.conf:/usr/local/etc/php-fpm.d/www.conf:ro
      - ./logs/php/tokoku:/var/log/php
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

### Step 4: Tambah Database di Script Init

Edit `database/init/01-create-databases.sh`:

```bash
#!/bin/bash
set -e

echo "=== Creating databases ==="

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    -- Database untuk hagiik.my.id
    CREATE DATABASE hagiik_db;
    CREATE USER hagiik_user WITH ENCRYPTED PASSWORD '${DB_HAGIIK_PASSWORD:-change_this}';
    GRANT ALL PRIVILEGES ON DATABASE hagiik_db TO hagiik_user;

    -- Database untuk tokoku.com (BARU)
    CREATE DATABASE tokoku_db;
    CREATE USER tokoku_user WITH ENCRYPTED PASSWORD '${DB_TOKOKU_PASSWORD:-change_this}';
    GRANT ALL PRIVILEGES ON DATABASE tokoku_db TO tokoku_user;

    -- Grant schema privileges untuk hagiik_db
    \c hagiik_db
    GRANT ALL ON SCHEMA public TO hagiik_user;

    -- Grant schema privileges untuk tokoku_db
    \c tokoku_db
    GRANT ALL ON SCHEMA public TO tokoku_user;
EOSQL

echo "=== Databases created successfully ==="
```

> ⚠️ **PENTING**: Script init hanya berjalan saat container database pertama kali dibuat.
> Jika database sudah ada, jalankan manual:
>
> ```bash
> docker compose exec database psql -U postgres
> # Lalu ketik command CREATE DATABASE... secara manual
> ```

### Step 5: Update .env.example

```env
# Domain 1
DOMAIN_SITE1=hagiik.my.id
DB_HAGIIK_PASSWORD=your_password

# Domain 2 (BARU)
DOMAIN_SITE2=tokoku.com
DB_TOKOKU_PASSWORD=your_password
```

### Step 6: Clone Laravel App di VPS

```bash
cd /docker/sites
git clone https://github.com/you/laravel-tokoku.git tokoku.com
```

### Step 7: Deploy

```bash
cd /docker

# Rebuild dan restart
docker compose up -d --build

# Setup SSL
./scripts/ssl-init.sh tokoku.com admin@tokoku.com

# Setup Laravel
docker compose exec site2 composer install --no-dev --optimize-autoloader
docker compose exec site2 php artisan key:generate
docker compose exec site2 php artisan migrate --force
docker compose exec site2 php artisan optimize
```

---

## 📊 Ringkasan: Apa yang Diubah

| No  | File                                   | Aksi                                  |
| --- | -------------------------------------- | ------------------------------------- |
| 1   | `nginx/nginx.conf`                     | Tambah `upstream siteX_backend`       |
| 2   | `nginx/sites-enabled/`                 | Buat file `newdomain.com.conf`        |
| 3   | `docker-compose.yml`                   | Tambah service `siteX` + volume nginx |
| 4   | `database/init/01-create-databases.sh` | Tambah database & user                |
| 5   | `.env.example`                         | Tambah variabel domain baru           |
| 6   | VPS: `sites/`                          | Clone Laravel project                 |

---

## 🔢 Pola Naming Convention

| Site | Upstream      | Container      | Database  | Folder       |
| ---- | ------------- | -------------- | --------- | ------------ |
| 1    | site1_backend | laravel-hagiik | hagiik_db | hagiik.my.id |
| 2    | site2_backend | laravel-tokoku | tokoku_db | tokoku.com   |
| 3    | site3_backend | laravel-xxx    | xxx_db    | xxx.com      |
| 4    | site4_backend | laravel-yyy    | yyy_db    | yyy.com      |

---

## 💡 Tips

### Gunakan Template

Simpan file config sebagai template:

```bash
cp nginx/sites-enabled/hagiik.my.id.conf nginx/sites-enabled/_template.conf.example
```

### Script Otomatis

Anda bisa membuat script untuk automasi langkah-langkah di atas!

### Memory Planning

Setiap PHP-FPM container butuh ~512MB RAM. Dengan 8GB RAM:

- 4 sites × 512MB = 2GB
- PostgreSQL = 1.5GB
- Redis = 256MB
- Nginx + OS = ~4GB
- **Total: ~8GB** (maksimal 4-5 sites)

---

## ⚠️ Troubleshooting

### Error: 502 Bad Gateway

Upstream tidak bisa connect ke PHP-FPM. Cek:

```bash
docker compose ps  # Pastikan container running
docker compose logs site2  # Cek error
```

### Error: File not found

Path tidak match. Pastikan:

- Volume nginx: `./sites/newdomain.com/public:/var/www/newdomain.com/public`
- SCRIPT_FILENAME di nginx config: `/var/www/html/public$fastcgi_script_name`

### Database tidak terbuat

Script init sudah dijalankan sebelumnya. Hapus volume dan recreate:

```bash
docker compose down
docker volume rm docker_postgres-data
docker compose up -d
```
