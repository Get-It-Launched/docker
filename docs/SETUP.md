# VPS Initial Setup Guide

Panduan lengkap untuk setup VPS Ubuntu baru dengan Docker untuk 4 Laravel websites.

---

## Prasyarat

- VPS dengan Ubuntu 22.04 atau 24.04 LTS
- Akses root atau sudo
- Domain sudah diarahkan ke IP VPS
- Minimal 8GB RAM

---

## Step 1: Update System & Install Dependencies

```bash
# Login sebagai root atau gunakan sudo
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y \
    curl \
    wget \
    git \
    unzip \
    htop \
    nano \
    ufw \
    fail2ban \
    ca-certificates \
    gnupg \
    lsb-release
```

---

## Step 2: Setup Firewall (UFW)

```bash
# Reset UFW (jika sudah ada konfigurasi sebelumnya)
sudo ufw --force reset

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (PENTING: lakukan ini dulu sebelum enable!)
sudo ufw allow 22/tcp

# Allow HTTP dan HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable UFW
sudo ufw --force enable

# Verify
sudo ufw status verbose
```

**Output yang diharapkan:**

```
Status: active
To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
```

---

## Step 3: Install Docker

```bash
# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group (optional, untuk non-root)
sudo usermod -aG docker $USER

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verify installation
docker --version
docker compose version
```

---

## Step 4: Create Directory Structure

```bash
# Create main docker directory
sudo mkdir -p /docker

# Set ownership (ganti 'your-user' dengan username Anda)
sudo chown -R $USER:$USER /docker

# Navigate to docker directory
cd /docker

# Clone atau copy konfigurasi Docker
# Option A: Dari Git repository
git clone https://github.com/your-repo/docker-config.git .

# Option B: Upload file secara manual via SCP
# scp -r ./Docker/* user@your-vps:/docker/
```

---

## Step 5: Create Required Directories

```bash
cd /docker

# Create directories
mkdir -p sites/test1.com
mkdir -p sites/test2.com
mkdir -p sites/test3.com
mkdir -p sites/test4.com
mkdir -p logs/nginx
mkdir -p logs/php/site1
mkdir -p logs/php/site2
mkdir -p logs/php/site3
mkdir -p logs/php/site4
mkdir -p certbot/conf
mkdir -p certbot/www
mkdir -p backups/database
mkdir -p nginx/ssl

# Set permissions for scripts
chmod +x scripts/*.sh
```

---

## Step 6: Configure Environment

```bash
cd /docker

# Copy environment file
cp .env.example .env

# Edit environment variables
nano .env
```

**Edit `.env` dengan nilai yang sesuai:**

```env
# Database - Gunakan password yang kuat!
DB_ROOT_PASSWORD=your_super_secure_root_password

DB_SITE1_USER=test1_user
DB_SITE1_PASSWORD=site1_secure_password
DB_SITE1_DATABASE=test1_db

DB_SITE2_USER=test2_user
DB_SITE2_PASSWORD=site2_secure_password
DB_SITE2_DATABASE=test2_db

# ... dst

# SSL Email
SSL_EMAIL=admin@yourdomain.com
```

---

## Step 7: Generate Self-Signed Certificate (Temporary)

Nginx memerlukan certificate untuk start. Buat self-signed cert sementara:

```bash
# Create SSL directory
mkdir -p /docker/nginx/ssl

# Generate self-signed certificate for default server
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /docker/nginx/ssl/default.key \
    -out /docker/nginx/ssl/default.crt \
    -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Temp/CN=localhost"
```

---

## Step 8: Clone Laravel Applications

```bash
# Site 1
cd /docker/sites/test1.com
git clone https://github.com/your-org/site1-laravel.git .
cp .env.example .env

# Edit .env Laravel
nano .env
```

**Contoh `.env` Laravel:**

```env
APP_NAME="Site 1"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://test1.com

LOG_CHANNEL=stack
LOG_LEVEL=warning

DB_CONNECTION=pgsql
DB_HOST=database          # <-- Nama container Docker
DB_PORT=5432
DB_DATABASE=test1_db
DB_USERNAME=test1_user
DB_PASSWORD=site1_secure_password

BROADCAST_DRIVER=log
CACHE_DRIVER=redis
FILESYSTEM_DISK=local
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis

REDIS_HOST=redis          # <-- Nama container Docker
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=mailpit
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@test1.com"
MAIL_FROM_NAME="${APP_NAME}"
```

Ulangi untuk site2, site3, dan site4.

---

## Step 9: Build and Start Containers

```bash
cd /docker

# Build PHP image
docker compose build

# Start all containers
docker compose up -d

# Check status
docker compose ps
```

**Output yang diharapkan:**

```
NAME              IMAGE                  STATUS        PORTS
laravel-site1    docker-php            Up 5 seconds
laravel-site2    docker-php            Up 5 seconds
laravel-site3    docker-php            Up 5 seconds
laravel-site4    docker-php            Up 5 seconds
nginx-proxy      nginx:1.25-alpine     Up 5 seconds   0.0.0.0:80->80, 0.0.0.0:443->443
postgres-db      postgres:16-alpine    Up 5 seconds
redis-cache      redis:7-alpine        Up 5 seconds
```

---

## Step 10: Setup Laravel Applications

```bash
# Site 1
docker compose exec site1 composer install --no-dev --optimize-autoloader
docker compose exec site1 php artisan key:generate
docker compose exec site1 php artisan storage:link
docker compose exec site1 php artisan migrate --force
docker compose exec site1 php artisan optimize

# Ulangi untuk site2, site3, site4
docker compose exec site2 composer install --no-dev --optimize-autoloader
docker compose exec site2 php artisan key:generate
# ... dst
```

---

## Step 11: Setup SSL Certificates

Pastikan domain sudah diarahkan ke IP VPS Anda terlebih dahulu!

```bash
cd /docker

# Install SSL untuk setiap domain
./scripts/ssl-init.sh test1.com admin@test1.com
./scripts/ssl-init.sh test2.com admin@test2.com
./scripts/ssl-init.sh test3.com admin@test3.com
./scripts/ssl-init.sh test4.com admin@test4.com
```

---

## Step 12: Setup Cron Jobs

```bash
# Edit crontab
crontab -e

# Add these lines:
# SSL renewal check (every 12 hours)
0 */12 * * * /docker/scripts/ssl-renew.sh >> /var/log/ssl-renew.log 2>&1

# Database backup (daily at 2 AM)
0 2 * * * /docker/scripts/backup-db.sh >> /var/log/db-backup.log 2>&1

# Laravel scheduler for each site (every minute)
* * * * * docker exec laravel-site1 php artisan schedule:run >> /dev/null 2>&1
* * * * * docker exec laravel-site2 php artisan schedule:run >> /dev/null 2>&1
* * * * * docker exec laravel-site3 php artisan schedule:run >> /dev/null 2>&1
* * * * * docker exec laravel-site4 php artisan schedule:run >> /dev/null 2>&1
```

---

## Step 13: Verify Installation

```bash
# Check all containers
docker compose ps

# Check logs
docker compose logs -f

# Test database connection
docker compose exec site1 php artisan tinker --execute="DB::connection()->getPdo(); echo 'Connected!';"

# Test HTTP
curl -I http://test1.com

# Test HTTPS
curl -I https://test1.com
```

---

## Step 14: Setup Fail2Ban (Optional but Recommended)

```bash
# Install fail2ban
sudo apt install -y fail2ban

# Create local config
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Edit config
sudo nano /etc/fail2ban/jail.local
```

Add/modify:

```ini
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /docker/logs/nginx/*.log
maxretry = 3
bantime = 3600
```

```bash
# Restart fail2ban
sudo systemctl restart fail2ban
sudo systemctl enable fail2ban
```

---

## Checklist Final

- [ ] UFW enabled dengan port 22, 80, 443
- [ ] Docker dan Docker Compose terinstall
- [ ] Semua container running
- [ ] SSL certificates terinstall untuk semua domain
- [ ] Laravel apps bisa diakses via HTTPS
- [ ] Database connection working
- [ ] Redis connection working
- [ ] Cron jobs configured
- [ ] Fail2ban setup (optional)
- [ ] Backup script tested

---

## Next Steps

1. Baca [DEPLOY.md](./DEPLOY.md) untuk panduan deployment
2. Baca [TROUBLESHOOT.md](./TROUBLESHOOT.md) jika ada masalah
