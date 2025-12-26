# Git Workflow untuk Docker VPS

Panduan tentang bagaimana mengelola repository Git untuk Docker config dan Laravel projects.

---

## 🔑 Konsep Utama

> **Docker Config dan Laravel Projects adalah REPOSITORY TERPISAH!**

Anda akan memiliki minimal 2 repository:

1. **Repository Docker Config** - berisi konfigurasi Docker, Nginx, PHP
2. **Repository Laravel App** - berisi aplikasi Laravel Anda (1 repo per project)

---

## 📦 Struktur Repository

```
GitHub/GitLab Anda:
├── docker-vps-config/        ← Repository 1: Konfigurasi Docker
│   ├── docker-compose.yml
│   ├── nginx/
│   ├── php/
│   ├── scripts/
│   └── docs/
│
├── laravel-site1/            ← Repository 2: Laravel App 1
│   ├── app/
│   ├── config/
│   ├── public/
│   └── ...
│
├── laravel-site2/            ← Repository 3: Laravel App 2
│   └── ...
│
├── laravel-site3/            ← Repository 4: Laravel App 3
│   └── ...
│
└── laravel-site4/            ← Repository 5: Laravel App 4
    └── ...
```

---

## 📂 Struktur di VPS

```
/docker/                      ← Clone dari docker-vps-config
├── docker-compose.yml
├── nginx/
├── php/
├── scripts/
├── docs/
│
└── sites/
    ├── test1.com/            ← Clone dari laravel-site1
    │   ├── app/
    │   ├── public/
    │   └── ...
    │
    ├── test2.com/            ← Clone dari laravel-site2
    ├── test3.com/            ← Clone dari laravel-site3
    └── test4.com/            ← Clone dari laravel-site4
```

---

## 🚀 Langkah-Langkah Deployment

### Step 1: Push Docker Config ke Git (Sekali Saja)

Di PC lokal Anda:

```bash
cd e:\Hagi-projects\Webdev\Docker

# Initialize git
git init
git add .
git commit -m "Initial Docker VPS configuration"

# Buat repository di GitHub, lalu:
git remote add origin https://github.com/USERNAME/docker-vps-config.git
git push -u origin main
```

### Step 2: Clone Docker Config ke VPS (Sekali Saja)

Di VPS:

```bash
# Clone docker config
git clone https://github.com/USERNAME/docker-vps-config.git /docker

# Setup environment
cd /docker
cp .env.example .env
nano .env  # Edit dengan password yang kuat!
```

### Step 3: Clone Laravel Projects ke VPS

Di VPS, untuk setiap Laravel project:

```bash
# Clone Laravel project ke folder sites
cd /docker/sites
git clone https://github.com/USERNAME/laravel-site1.git test1.com
git clone https://github.com/USERNAME/laravel-site2.git test2.com
git clone https://github.com/USERNAME/laravel-site3.git test3.com
git clone https://github.com/USERNAME/laravel-site4.git test4.com
```

### Step 4: Setup Laravel Apps

```bash
# Untuk setiap site, jalankan:
cd /docker/sites/test1.com
cp .env.example .env
nano .env  # Edit DB_HOST=database, REDIS_HOST=redis, dll

# Lalu via Docker:
cd /docker
docker compose exec site1 composer install --no-dev --optimize-autoloader
docker compose exec site1 php artisan key:generate
docker compose exec site1 php artisan migrate --force
docker compose exec site1 php artisan optimize
```

---

## 🔄 Workflow Update

### Update Docker Config

Jika Anda mengubah konfigurasi Nginx, PHP, atau docker-compose:

```bash
# Di PC lokal
cd e:\Hagi-projects\Webdev\Docker
git add .
git commit -m "Update nginx config"
git push

# Di VPS
cd /docker
git pull origin main
docker compose restart nginx  # atau service yang diubah
```

### Update Laravel App

Jika Anda mengubah code Laravel:

```bash
# Di PC lokal (folder project Laravel Anda)
git add .
git commit -m "Add new feature"
git push

# Di VPS
cd /docker/sites/test1.com
git pull origin main

# Jalankan deployment commands
cd /docker
docker compose exec site1 composer install --no-dev --optimize-autoloader
docker compose exec site1 php artisan migrate --force
docker compose exec site1 php artisan optimize
```

Atau gunakan script deploy:

```bash
./scripts/deploy.sh site1 full
```

---

## 📋 Ringkasan

| Aksi                       | Repository          | Lokasi di VPS              |
| -------------------------- | ------------------- | -------------------------- |
| Update Docker/Nginx config | `docker-vps-config` | `/docker/`                 |
| Update Laravel site 1      | `laravel-site1`     | `/docker/sites/test1.com/` |
| Update Laravel site 2      | `laravel-site2`     | `/docker/sites/test2.com/` |
| Update Laravel site 3      | `laravel-site3`     | `/docker/sites/test3.com/` |
| Update Laravel site 4      | `laravel-site4`     | `/docker/sites/test4.com/` |

---

## ⚠️ Penting!

1. **Jangan masukkan Laravel projects ke dalam repo docker-config**

   - Mereka adalah repo terpisah!

2. **Jangan commit file `.env` ke Git**

   - File `.env` berisi password dan secrets
   - Sudah ada di `.gitignore`

3. **Folder `sites/` di repo docker-config kosong**

   - Laravel apps di-clone langsung di VPS
   - Bukan bagian dari repo docker-config

4. **Setiap Laravel project punya repo sendiri**
   - Memudahkan collaboration per project
   - Bisa update satu site tanpa ganggu yang lain

---

## 💡 Tips

### Menggunakan SSH Key untuk Git

Agar tidak perlu input password setiap git pull:

```bash
# Di VPS, generate SSH key
ssh-keygen -t ed25519 -C "your-email@example.com"

# Copy public key
cat ~/.ssh/id_ed25519.pub

# Tambahkan ke GitHub: Settings → SSH Keys → New SSH Key

# Clone dengan SSH URL
git clone git@github.com:USERNAME/laravel-site1.git test1.com
```

### Alias untuk Deployment

Tambahkan di `~/.bashrc`:

```bash
alias deploy1="cd /docker && ./scripts/deploy.sh site1 full"
alias deploy2="cd /docker && ./scripts/deploy.sh site2 full"
alias deploy3="cd /docker && ./scripts/deploy.sh site3 full"
alias deploy4="cd /docker && ./scripts/deploy.sh site4 full"
```

Kemudian cukup ketik `deploy1` untuk deploy site1.
