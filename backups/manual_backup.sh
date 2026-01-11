#!/bin/bash

# Manual backup script for MariaDB databases
# Backs up bigcapital_system and all bigcapital_* tenant databases individually

# Configuration - set these environment variables or modify here
DB_HOST=${DB_HOST:-host.docker.internal}  # Default to host for hostdb setup
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
SYSTEM_DB_NAME=${SYSTEM_DB_NAME:-bigcapital_system}
TENANT_DB_PREFIX=${TENANT_DB_NAME_PREFIX:-bigcapital_}  # Match actual tenant naming

# Backup directory - defaults to ./backups/bigcapital (relative to script location)
# Override with BACKUP_DIR environment variable for different paths
BACKUP_DIR=${BACKUP_DIR:-./backups/bigcapital}
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "Starting manual backup..."
echo "Host: $DB_HOST"
echo "System DB: $SYSTEM_DB_NAME"
echo "Tenant DB Prefix: $TENANT_DB_PREFIX"
echo "Backup directory: $BACKUP_DIR"

# Get list of tenant databases (exclude system db)
TENANT_DBS=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" -e "SHOW DATABASES LIKE '${TENANT_DB_PREFIX}%';" 2>/dev/null | grep -v "Database" | grep -v "^${SYSTEM_DB_NAME}$")

if [ $? -ne 0 ]; then
    echo "Error: Failed to connect to MySQL or list databases"
    exit 1
fi

echo "Found tenant databases: $TENANT_DBS"

# Backup system database
echo "Backing up system database: $SYSTEM_DB_NAME"
SYSTEM_BACKUP_FILE="$BACKUP_DIR/mariadb_${SYSTEM_DB_NAME}_$TIMESTAMP.sql.gz"
mysqldump -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" --single-transaction --routines --triggers --events "$SYSTEM_DB_NAME" 2>/dev/null | gzip > "$SYSTEM_BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "✅ System database backup completed: $SYSTEM_BACKUP_FILE"
    echo "   Size: $(du -h "$SYSTEM_BACKUP_FILE" | cut -f1)"
else
    echo "❌ Error: System database backup failed"
    exit 1
fi

# Backup each tenant database individually
for DB in $TENANT_DBS; do
    echo "Backing up tenant database: $DB"
    TENANT_BACKUP_FILE="$BACKUP_DIR/mariadb_${DB}_$TIMESTAMP.sql.gz"
    mysqldump -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" --single-transaction --routines --triggers --events "$DB" 2>/dev/null | gzip > "$TENANT_BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        echo "✅ Tenant database backup completed: $TENANT_BACKUP_FILE"
        echo "   Size: $(du -h "$TENANT_BACKUP_FILE" | cut -f1)"
    else
        echo "❌ Error: Tenant database backup failed for $DB"
        exit 1
    fi
done

echo "🎉 All backups completed successfully!"
echo "📁 Backup files created in: $BACKUP_DIR"
echo "💡 To use a different backup directory, set: BACKUP_DIR=/path/to/backups"
echo "   - mariadb_${SYSTEM_DB_NAME}_$TIMESTAMP.sql.gz"
for DB in $TENANT_DBS; do
    echo "   - mariadb_${DB}_$TIMESTAMP.sql.gz"
done