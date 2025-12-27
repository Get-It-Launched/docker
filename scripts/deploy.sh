#!/bin/bash
# =============================================================================
# Laravel Deployment Script
# Usage: ./deploy.sh <site> [full|quick]
# Example: ./deploy.sh hagiik.my.id full
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOCKER_DIR="/docker"
SITES_DIR="${DOCKER_DIR}/sites"

# Functions
print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

show_usage() {
    echo "Usage: $0 <site> [full|quick]"
    echo ""
    echo "Sites: hagiik.my.id, site2, site3, site4"
    echo ""
    echo "Modes:"
    echo "  full  - Git pull + composer install + npm build + all caches"
    echo "  quick - Git pull + clear cache only"
    echo ""
    echo "Examples:"
    echo "  $0 hagiik.my.id full   # Full deployment for hagiik.my.id"
    echo "  $0 site2 quick         # Quick update for site2"
    exit 1
}

# Validate arguments
if [ $# -lt 1 ]; then
    show_usage
fi

SITE=$1
MODE=${2:-full}

# Validate site
case $SITE in
    hagiik.my.id|site2|site3|site4)
        ;;
    *)
        print_error "Invalid site: $SITE"
        show_usage
        ;;
esac

# Map site to domain and container name
case $SITE in
    hagiik.my.id) DOMAIN="hagiik.my.id"; CONTAINER="hagiik_my_id" ;;
    site2) DOMAIN="test2.com"; CONTAINER="site2" ;;
    site3) DOMAIN="test3.com"; CONTAINER="site3" ;;
    site4) DOMAIN="test4.com"; CONTAINER="site4" ;;
esac

SITE_DIR="${SITES_DIR}/${DOMAIN}"

print_header "Deploying ${DOMAIN} (${MODE} mode)"

# Check if site directory exists
if [ ! -d "$SITE_DIR" ]; then
    print_error "Site directory not found: $SITE_DIR"
    exit 1
fi

cd "$SITE_DIR"

# =============================================================================
# Deployment Steps
# =============================================================================

# 1. Enable maintenance mode
print_header "Step 1: Enabling maintenance mode"
docker compose exec $CONTAINER php artisan down --retry=60 || true
print_success "Maintenance mode enabled"

# 2. Git pull
print_header "Step 2: Pulling latest code"
git pull origin main
print_success "Code updated"

if [ "$MODE" == "full" ]; then
    # 3. Composer install
    print_header "Step 3: Installing Composer dependencies"
    docker compose exec $CONTAINER composer install --no-dev --optimize-autoloader
    print_success "Composer dependencies installed"
    
    # 4. NPM build (if package.json exists)
    if [ -f "package.json" ]; then
        print_header "Step 4: Building frontend assets"
        docker compose exec $CONTAINER npm ci
        docker compose exec $CONTAINER npm run build
        print_success "Frontend assets built"
    else
        print_warning "Step 4: No package.json found, skipping npm build"
    fi
    
    # 5. Run migrations
    print_header "Step 5: Running database migrations"
    docker compose exec $CONTAINER php artisan migrate --force
    print_success "Migrations completed"
fi

# 6. Clear and rebuild caches
print_header "Step 6: Optimizing application"
docker compose exec $CONTAINER php artisan optimize:clear
docker compose exec $CONTAINER php artisan optimize
docker compose exec $CONTAINER php artisan view:cache
print_success "Application optimized"

# 7. Set permissions
print_header "Step 7: Setting file permissions"
docker compose exec $CONTAINER chown -R www-data:www-data storage bootstrap/cache
docker compose exec $CONTAINER chmod -R 775 storage bootstrap/cache
print_success "Permissions set"

# 8. Disable maintenance mode
print_header "Step 8: Disabling maintenance mode"
docker compose exec $CONTAINER php artisan up
print_success "Maintenance mode disabled"

# =============================================================================
# Done
# =============================================================================

print_header "Deployment Complete!"
echo -e "${GREEN}Site ${DOMAIN} has been successfully deployed.${NC}"
echo ""
echo "Verify at: https://${DOMAIN}"
