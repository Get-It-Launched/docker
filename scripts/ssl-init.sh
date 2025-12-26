#!/bin/bash
# =============================================================================
# SSL Certificate Initialization Script
# Usage: ./ssl-init.sh <domain> <email>
# Example: ./ssl-init.sh test1.com admin@test1.com
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOCKER_DIR="/docker"

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

show_usage() {
    echo "Usage: $0 <domain> <email>"
    echo ""
    echo "Examples:"
    echo "  $0 test1.com admin@test1.com"
    echo "  $0 test2.com admin@test2.com"
    echo ""
    echo "This script will:"
    echo "  1. Start nginx in HTTP-only mode"
    echo "  2. Request certificate from Let's Encrypt"
    echo "  3. Reload nginx with SSL configuration"
    exit 1
}

# Validate arguments
if [ $# -lt 2 ]; then
    show_usage
fi

DOMAIN=$1
EMAIL=$2

print_header "SSL Certificate Setup for ${DOMAIN}"

cd "$DOCKER_DIR"

# =============================================================================
# Step 1: Create temporary nginx config (HTTP only)
# =============================================================================

print_header "Step 1: Preparing HTTP-only nginx config"

# Backup current config
if [ -f "nginx/sites-enabled/${DOMAIN}.conf" ]; then
    cp "nginx/sites-enabled/${DOMAIN}.conf" "nginx/sites-enabled/${DOMAIN}.conf.bak"
fi

# Create temporary HTTP-only config
cat > "nginx/sites-enabled/${DOMAIN}.conf.tmp" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }
    
    location / {
        return 200 "Challenge server ready";
        add_header Content-Type text/plain;
    }
}
EOF

# Temporarily use HTTP-only config
mv "nginx/sites-enabled/${DOMAIN}.conf" "nginx/sites-enabled/${DOMAIN}.conf.ssl" 2>/dev/null || true
mv "nginx/sites-enabled/${DOMAIN}.conf.tmp" "nginx/sites-enabled/${DOMAIN}.conf"

print_success "HTTP-only config created"

# =============================================================================
# Step 2: Reload nginx
# =============================================================================

print_header "Step 2: Reloading nginx"

docker compose exec nginx nginx -t
docker compose exec nginx nginx -s reload

print_success "Nginx reloaded"

# Wait for nginx to be ready
sleep 2

# =============================================================================
# Step 3: Request certificate
# =============================================================================

print_header "Step 3: Requesting SSL certificate"

# Create webroot directory if not exists
mkdir -p certbot/www

# Request certificate
docker compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    -d ${DOMAIN} \
    -d www.${DOMAIN} \
    --email ${EMAIL} \
    --agree-tos \
    --no-eff-email \
    --non-interactive

print_success "Certificate obtained"

# =============================================================================
# Step 4: Restore SSL config
# =============================================================================

print_header "Step 4: Restoring SSL nginx config"

# Restore SSL config
if [ -f "nginx/sites-enabled/${DOMAIN}.conf.ssl" ]; then
    mv "nginx/sites-enabled/${DOMAIN}.conf.ssl" "nginx/sites-enabled/${DOMAIN}.conf"
else
    # Restore from backup
    mv "nginx/sites-enabled/${DOMAIN}.conf.bak" "nginx/sites-enabled/${DOMAIN}.conf"
fi

print_success "SSL config restored"

# =============================================================================
# Step 5: Reload nginx with SSL
# =============================================================================

print_header "Step 5: Reloading nginx with SSL"

docker compose exec nginx nginx -t
docker compose exec nginx nginx -s reload

print_success "Nginx reloaded with SSL"

# =============================================================================
# Done
# =============================================================================

print_header "SSL Setup Complete!"
echo -e "${GREEN}Certificate for ${DOMAIN} has been installed.${NC}"
echo ""
echo "Certificate location:"
echo "  /docker/certbot/conf/live/${DOMAIN}/fullchain.pem"
echo "  /docker/certbot/conf/live/${DOMAIN}/privkey.pem"
echo ""
echo "Test at: https://${DOMAIN}"

# Cleanup
rm -f "nginx/sites-enabled/${DOMAIN}.conf.bak"
rm -f "nginx/sites-enabled/${DOMAIN}.conf.tmp"
