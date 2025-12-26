#!/bin/bash
# =============================================================================
# Database Backup Script
# Usage: ./backup-db.sh [database_name]
# Example: ./backup-db.sh test1_db
# =============================================================================

set -e

# Configuration
DOCKER_DIR="/docker"
BACKUP_DIR="${DOCKER_DIR}/backups/database"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

cd "$DOCKER_DIR"

# =============================================================================
# Backup Functions
# =============================================================================

backup_database() {
    local db_name=$1
    local backup_file="${BACKUP_DIR}/${db_name}_${DATE}.sql.gz"
    
    echo "Backing up database: ${db_name}"
    
    docker compose exec -T database pg_dump \
        -U postgres \
        --clean \
        --if-exists \
        --no-owner \
        --no-privileges \
        "$db_name" | gzip > "$backup_file"
    
    if [ $? -eq 0 ]; then
        local size=$(du -h "$backup_file" | cut -f1)
        print_success "Backup created: ${backup_file} (${size})"
    else
        print_error "Failed to backup ${db_name}"
        rm -f "$backup_file"
        return 1
    fi
}

backup_all_databases() {
    local databases=("test1_db" "test2_db" "test3_db" "test4_db")
    
    for db in "${databases[@]}"; do
        backup_database "$db"
    done
}

cleanup_old_backups() {
    echo ""
    echo "Cleaning up backups older than ${RETENTION_DAYS} days..."
    
    local deleted=$(find "$BACKUP_DIR" -name "*.sql.gz" -mtime +${RETENTION_DAYS} -type f -delete -print | wc -l)
    
    if [ "$deleted" -gt 0 ]; then
        print_success "Deleted ${deleted} old backup(s)"
    else
        echo "No old backups to delete"
    fi
}

# =============================================================================
# Main
# =============================================================================

print_header "PostgreSQL Database Backup"

if [ $# -eq 1 ]; then
    # Backup specific database
    backup_database "$1"
else
    # Backup all databases
    backup_all_databases
fi

# Cleanup old backups
cleanup_old_backups

# Show backup summary
print_header "Backup Summary"
echo "Backup directory: ${BACKUP_DIR}"
echo ""
echo "Recent backups:"
ls -lh "$BACKUP_DIR"/*.sql.gz 2>/dev/null | tail -10 || echo "No backups found"
echo ""
echo "Total backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"
