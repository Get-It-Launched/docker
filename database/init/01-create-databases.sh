#!/bin/bash
# =============================================================================
# PostgreSQL Initialization Script
# Creates database and user for hagiik.my.id
# =============================================================================

set -e

echo "=== Creating database for hagiik.my.id ==="

# Create database and user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    -- Create database
    CREATE DATABASE hagiik_db;
    
    -- Create user (use environment variable or default)
    CREATE USER hagiik_user WITH ENCRYPTED PASSWORD '${DB_HAGIIK_PASSWORD:-change_this_password}';
    
    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE hagiik_db TO hagiik_user;
    
    -- Connect to database and grant schema privileges
    \c hagiik_db
    GRANT ALL ON SCHEMA public TO hagiik_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO hagiik_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO hagiik_user;
EOSQL

echo "=== Database hagiik_db created successfully ==="
