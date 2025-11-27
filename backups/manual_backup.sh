#!/bin/bash

# Manual backup script for MariaDB databases
# Backs up bigcapital_system and all bigcapital_tenant_* databases

# Configuration - set these environment variables or modify here
DB_HOST=${DB_HOST:-mysql}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
SYSTEM_DB_NAME=${SYSTEM_DB_NAME:-bigcapital_system}
TENANT_DB_PREFIX=${TENANT_DB_NAME_PREFIX:-bigcapital_tenant_}

# Backup directory
BACKUP_DIR=${BACKUP_DIR:-./backups}
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/mysql_$TIMESTAMP.sql.gz"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "Starting manual backup..."
echo "Host: $DB_HOST"
echo "System DB: $SYSTEM_DB_NAME"
echo "Tenant DB Prefix: $TENANT_DB_PREFIX"
echo "Backup file: $BACKUP_FILE"

# Get list of tenant databases
TENANT_DBS=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" -e "SHOW DATABASES LIKE '${TENANT_DB_PREFIX}%';" 2>/dev/null | grep -v "Database")

if [ $? -ne 0 ]; then
    echo "Error: Failed to connect to MySQL or list databases"
    exit 1
fi

# Combine system DB and tenant DBs
ALL_DBS="$SYSTEM_DB_NAME $TENANT_DBS"

echo "Databases to backup: $ALL_DBS"

# Perform backup
mysqldump -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" --single-transaction --routines --triggers --events --databases $ALL_DBS 2>/dev/null | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Backup completed successfully: $BACKUP_FILE"
    echo "Size: $(du -h "$BACKUP_FILE" | cut -f1)"
    # Copy to host backups if running in container
    if [ -d "/host-backups" ]; then
        cp "$BACKUP_FILE" /host-backups/ 2>/dev/null || true
        echo "Copied to host: /host-backups/$(basename "$BACKUP_FILE")"
    fi
else
    echo "Error: Backup failed"
    exit 1
fi