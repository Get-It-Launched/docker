#!/bin/bash
# =============================================================================
# SSL Certificate Renewal Script
# Run via cron: 0 */12 * * * /docker/scripts/ssl-renew.sh >> /var/log/ssl-renew.log 2>&1
# =============================================================================

set -e

DOCKER_DIR="/docker"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

echo "${LOG_PREFIX} Starting SSL certificate renewal check..."

cd "$DOCKER_DIR"

# Run certbot renewal
docker compose run --rm certbot renew --quiet

# Check if any certificate was renewed
if [ $? -eq 0 ]; then
    echo "${LOG_PREFIX} Certificate renewal check completed."
    
    # Reload nginx to pick up new certificates
    docker compose exec nginx nginx -s reload
    echo "${LOG_PREFIX} Nginx reloaded."
else
    echo "${LOG_PREFIX} Certificate renewal failed!"
    exit 1
fi

echo "${LOG_PREFIX} SSL renewal process completed."
