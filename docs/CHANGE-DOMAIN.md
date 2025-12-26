# Panduan Mengganti Domain

Panduan langkah demi langkah untuk mengganti domain placeholder (`test1.com`, `test2.com`, dll)
menjadi domain asli Anda.

---

## 🎯 Overview

Saat setup awal, kita menggunakan domain placeholder:

- `test1.com` → Domain website 1
- `test2.com` → Domain website 2
- `test3.com` → Domain website 3
- `test4.com` → Domain website 4

Ketika Anda sudah memiliki domain asli, ikuti panduan ini untuk menggantinya.

---

## 📝 Contoh Skenario

Misalkan domain asli Anda adalah:
| Placeholder | Domain Asli |
|-------------|-------------|
| test1.com | tokoonline.com |
| test2.com | blogku.id |
| test3.com | portfolio.dev |
| test4.com | apiku.co.id |

---

## 🔧 Langkah-Langkah

### Step 1: Rename File Konfigurasi Nginx

```bash
cd /docker/nginx/sites-enabled

# Rename file config
mv test1.com.conf tokoonline.com.conf
mv test2.com.conf blogku.id.conf
mv test3.com.conf portfolio.dev.conf
mv test4.com.conf apiku.co.id.conf
```

### Step 2: Edit Isi File Nginx Config

Untuk setiap file `.conf`, ganti semua referensi domain:

**Contoh: `tokoonline.com.conf`**

```nginx
# SEBELUM:
server_name test1.com www.test1.com;
ssl_certificate /etc/letsencrypt/live/test1.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/test1.com/privkey.pem;
access_log /var/log/nginx/test1.com.access.log main;
error_log /var/log/nginx/test1.com.error.log warn;
root /var/www/test1.com/public;

# SESUDAH:
server_name tokoonline.com www.tokoonline.com;
ssl_certificate /etc/letsencrypt/live/tokoonline.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/tokoonline.com/privkey.pem;
access_log /var/log/nginx/tokoonline.com.access.log main;
error_log /var/log/nginx/tokoonline.com.error.log warn;
root /var/www/tokoonline.com/public;
```

**Gunakan Find & Replace di VS Code:**

1. Buka file config
2. Tekan `Ctrl+H`
3. Find: `test1.com`
4. Replace: `tokoonline.com`
5. Klik "Replace All"

### Step 3: Rename Folder Sites

```bash
cd /docker/sites

# Rename folder
mv test1.com tokoonline.com
mv test2.com blogku.id
mv test3.com portfolio.dev
mv test4.com apiku.co.id
```

### Step 4: Update docker-compose.yml

Edit `docker-compose.yml` dan ganti semua referensi domain:

```yaml
# SEBELUM:
nginx:
  volumes:
    - ./sites/test1.com/public:/var/www/test1.com/public:ro
    - ./sites/test2.com/public:/var/www/test2.com/public:ro
    ...

site1:
  volumes:
    - ./sites/test1.com:/var/www/html
    ...

# SESUDAH:
nginx:
  volumes:
    - ./sites/tokoonline.com/public:/var/www/tokoonline.com/public:ro
    - ./sites/blogku.id/public:/var/www/blogku.id/public:ro
    ...

site1:
  volumes:
    - ./sites/tokoonline.com:/var/www/html
    ...
```

### Step 5: Update .env

```env
# SEBELUM:
DOMAIN_SITE1=test1.com
DOMAIN_SITE2=test2.com
DOMAIN_SITE3=test3.com
DOMAIN_SITE4=test4.com

# SESUDAH:
DOMAIN_SITE1=tokoonline.com
DOMAIN_SITE2=blogku.id
DOMAIN_SITE3=portfolio.dev
DOMAIN_SITE4=apiku.co.id

SSL_EMAIL=admin@tokoonline.com
```

### Step 6: Restart Containers

```bash
cd /docker

# Recreate containers dengan config baru
docker compose down
docker compose up -d
```

### Step 7: Setup SSL untuk Domain Baru

```bash
# Jalankan untuk setiap domain
./scripts/ssl-init.sh tokoonline.com admin@tokoonline.com
./scripts/ssl-init.sh blogku.id admin@blogku.id
./scripts/ssl-init.sh portfolio.dev admin@portfolio.dev
./scripts/ssl-init.sh apiku.co.id admin@apiku.co.id
```

---

## ⚠️ Penting: Sebelum Menjalankan SSL

Pastikan domain sudah diarahkan ke IP VPS Anda:

1. Login ke **panel domain registrar** (Niagahoster, Namecheap, Cloudflare, dll)
2. Set **DNS A Record**:

   ```
   Type: A
   Name: @
   Value: <IP_VPS_ANDA>
   TTL: 300

   Type: A
   Name: www
   Value: <IP_VPS_ANDA>
   TTL: 300
   ```

3. Tunggu propagasi DNS (5-30 menit)
4. Verifikasi dengan: `ping tokoonline.com`

---

## 🔍 Quick Reference: Yang Perlu Diganti

| File/Folder                  | Yang Diganti                                                    |
| ---------------------------- | --------------------------------------------------------------- |
| `nginx/sites-enabled/*.conf` | Filename + isi (server_name, ssl_certificate, access_log, root) |
| `sites/`                     | Nama folder                                                     |
| `docker-compose.yml`         | Volume paths                                                    |
| `.env`                       | DOMAIN_SITE1, DOMAIN_SITE2, dst                                 |
| `scripts/`                   | Tidak perlu (sudah dynamic)                                     |

---

## 💡 Tips: Gunakan Find & Replace Global

Di **VS Code**, gunakan Find & Replace di seluruh folder:

1. Tekan `Ctrl+Shift+H`
2. Search: `test1.com`
3. Replace: `tokoonline.com`
4. Files to include: `*` (semua file)
5. Klik ikon "Replace All"

Ulangi untuk semua domain (test2.com, test3.com, test4.com).

---

## ✅ Checklist Setelah Ganti Domain

- [ ] File nginx config sudah di-rename
- [ ] Isi nginx config sudah diganti
- [ ] Folder sites sudah di-rename
- [ ] docker-compose.yml sudah diupdate
- [ ] .env sudah diupdate
- [ ] DNS sudah diarahkan ke VPS
- [ ] SSL certificate sudah di-generate
- [ ] Website bisa diakses via HTTPS

---

## 🆘 Troubleshooting

### Error: SSL certificate not found

SSL belum di-generate. Jalankan `./scripts/ssl-init.sh`.

### Error: File not found

Pastikan nama folder di `sites/` sama dengan path di `docker-compose.yml`.

### Website tidak bisa diakses

1. Cek DNS sudah propagate: `nslookup yourdomain.com`
2. Cek nginx config: `docker compose exec nginx nginx -t`
3. Cek logs: `docker compose logs nginx`
