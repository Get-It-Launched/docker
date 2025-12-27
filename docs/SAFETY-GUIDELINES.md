# ⚠️ SAFETY GUIDELINES - BACA SEBELUM MELAKUKAN APAPUN!

> **PENTING**: Dokumentasi ini berisi aturan keamanan untuk mencegah kehilangan data.
> Setiap AI assistant atau developer WAJIB membaca ini sebelum melakukan perubahan.

---

## 🚫 JANGAN PERNAH JALANKAN COMMAND INI!

```bash
# ❌ BAHAYA - MENGHAPUS SEMUA DATA DATABASE!
docker compose down -v
docker compose down --volumes

# ❌ BAHAYA - MENGHAPUS VOLUME DATABASE!
docker volume rm docker_postgres-data
docker volume rm docker_redis-data

# ❌ BAHAYA - MENGHAPUS SEMUA DATA!
docker system prune -a --volumes
docker volume prune

# ❌ BAHAYA - DROP DATABASE!
DROP DATABASE wedlistfy_db;
DROP DATABASE hagiik_db;
```

---

## ✅ COMMAND YANG AMAN

```bash
# ✅ AMAN - Stop & start container (data tetap ada)
docker compose down
docker compose up -d

# ✅ AMAN - Rebuild container (data tetap ada)
docker compose down
docker compose up -d --build

# ✅ AMAN - Restart specific service
docker compose restart nginx
docker compose restart wedlistfy_com

# ✅ AMAN - View logs
docker compose logs nginx --tail=50
docker compose logs -f  # follow logs

# ✅ AMAN - Enter container
docker compose exec wedlistfy_com bash
docker compose exec database psql -U postgres
```

---

## 📦 Struktur Data Penting

### Data yang PERSISTENT (Tidak hilang saat rebuild):

| Data | Lokasi | Backup? |
|------|--------|---------|
| PostgreSQL Database | Docker Volume `postgres-data` | ⚠️ Perlu backup manual |
| Redis Cache | Docker Volume `redis-data` | ❌ Tidak perlu |
| SSL Certificates | `/docker/certbot/conf/` | ⚠️ Bisa di-generate ulang |
| Laravel Projects | `/docker/sites/*/` | ✅ Ada di Git |
| Laravel .env | `/docker/sites/*/.env` | ⚠️ Perlu backup manual |
| Uploaded Files | `/docker/sites/*/storage/` | ⚠️ Perlu backup manual |

### Data yang TIDAK di-track Git:

```
/docker/
├── .env                    # ⚠️ Credentials - backup manual!
├── certbot/conf/           # SSL certificates - bisa regenerate
├── sites/*/                # Laravel projects - repo terpisah
│   ├── .env               # ⚠️ Credentials - backup manual!
│   ├── storage/app/       # ⚠️ Uploaded files - backup!
│   └── vendor/            # Bisa di-regenerate
└── logs/                   # Bisa dihapus
```

---

## 💾 Backup Database

### Backup Manual
```bash
# Backup semua database
docker compose exec database pg_dumpall -U postgres > /backup/full_backup_$(date +%Y%m%d).sql

# Backup database spesifik
docker compose exec database pg_dump -U postgres wedlistfy_db > /backup/wedlistfy_$(date +%Y%m%d).sql
docker compose exec database pg_dump -U postgres hagiik_db > /backup/hagiik_$(date +%Y%m%d).sql
```

### Restore Database
```bash
# Restore full backup
cat /backup/full_backup.sql | docker compose exec -T database psql -U postgres

# Restore database spesifik
cat /backup/wedlistfy.sql | docker compose exec -T database psql -U postgres wedlistfy_db
```

### Backup .env Files
```bash
# Backup semua .env
cp /docker/.env /backup/docker_env_$(date +%Y%m%d)
cp /docker/sites/wedlistfy.com/.env /backup/wedlistfy_env_$(date +%Y%m%d)
cp /docker/sites/hagiik.my.id/.env /backup/hagiik_env_$(date +%Y%m%d)
```

### Backup Uploaded Files
```bash
# Backup storage
tar -czvf /backup/wedlistfy_storage_$(date +%Y%m%d).tar.gz /docker/sites/wedlistfy.com/storage/app
tar -czvf /backup/hagiik_storage_$(date +%Y%m%d).tar.gz /docker/sites/hagiik.my.id/storage/app
```

---

## 🔄 Alur Update yang Aman

### Update Docker Config (dari local ke VPS):
```bash
# 1. Di LOCAL: commit & push
git add .
git commit -m "Update config"
git push origin main

# 2. Di VPS: pull & rebuild
cd /docker
git pull origin main
docker compose down          # ✅ TANPA -v
docker compose up -d --build
```

### Update Laravel Code:
```bash
# Di VPS
cd /docker/sites/wedlistfy.com
git pull origin main
docker compose exec wedlistfy_com composer install --no-dev --optimize-autoloader
docker compose exec wedlistfy_com php artisan migrate --force
docker compose exec wedlistfy_com php artisan optimize
```

---

## 🛡️ Checklist Sebelum Maintenance

- [ ] Backup database sudah dibuat
- [ ] Backup .env files sudah dibuat
- [ ] Backup uploaded files (jika ada)
- [ ] Tidak ada user yang sedang aktif (jika perlu downtime)
- [ ] Sudah test di staging/local terlebih dahulu

---

## 📋 Informasi Environment

### Sites yang Aktif:
| Domain | Container | Database | Status |
|--------|-----------|----------|--------|
| wedlistfy.com | wedlistfy_com | wedlistfy_db | ✅ Active |
| hagiik.my.id | hagiik_my_id | hagiik_db | ⚠️ SSL Pending |
| launchify.co.id | launchify_co_id | launchify_db | ⏳ Domain Belum Aktif |

### Credentials Location:
- Docker env: `/docker/.env`
- Laravel env: `/docker/sites/{domain}/.env`
- Database: lihat `.env` files

### IP & Access:
- VPS IP: `72.61.215.75`
- SSH: `ssh root@72.61.215.75`

---

## 🆘 Emergency Recovery

### Jika Database Hilang:
1. Jangan panik
2. Cek backup di `/backup/`
3. Restore dari backup terakhir

### Jika SSL Error:
```bash
# Regenerate self-signed (temporary)
mkdir -p /docker/certbot/conf/live/DOMAIN
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /docker/certbot/conf/live/DOMAIN/privkey.pem \
    -out /docker/certbot/conf/live/DOMAIN/fullchain.pem \
    -subj "/CN=DOMAIN"
docker compose restart nginx
```

### Jika Container Crash Loop:
```bash
# Check logs
docker compose logs CONTAINER --tail=100

# Rebuild specific container
docker compose build --no-cache CONTAINER
docker compose up -d
```

---

## 📞 Kontak Darurat

Jika ada masalah kritis:
- Email: hagiihsank@gmail.com
- Backup lokasi: `/backup/`
