#!/bin/bash

# Manual restore script for MariaDB backups
# Restores from individual compressed .sql.gz backup files

# Configuration - set these environment variables or modify here
DB_HOST=${DB_HOST:-host.docker.internal}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}

# Check if backup file pattern is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_timestamp>"
    echo "Example: $0 20260111_143000"
    echo ""
    echo "This will restore all backup files matching the timestamp:"
    echo "  - mariadb_bigcapital_system_<timestamp>.sql.gz"
    echo "  - mariadb_bigcapital_*_<timestamp>.sql.gz"
    exit 1
fi

TIMESTAMP=$1
BACKUP_DIR=${BACKUP_DIR:-./backups/bigcapital}  # Match backup script default

echo "Starting MariaDB restore..."
echo "Host: $DB_HOST"
echo "Timestamp: $TIMESTAMP"
echo "Backup directory: $BACKUP_DIR"

# Find all backup files for this timestamp
SYSTEM_BACKUP="$BACKUP_DIR/mariadb_bigcapital_system_$TIMESTAMP.sql.gz"
TENANT_BACKUPS=$(ls -1 "$BACKUP_DIR"/mariadb_bigcapital_*$TIMESTAMP.sql.gz 2>/dev/null | grep -v "bigcapital_system")

if [ ! -f "$SYSTEM_BACKUP" ]; then
    echo "❌ Error: System database backup not found: $SYSTEM_BACKUP"
    exit 1
fi

echo "Found system backup: $SYSTEM_BACKUP"
echo "Found tenant backups:"
echo "$TENANT_BACKUPS" | sed 's/^/  - /'

# Confirm before restore
echo ""
echo "⚠️  WARNING: This will overwrite existing databases!"
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 0
fi

# Restore system database first
echo "Restoring system database from $SYSTEM_BACKUP..."
gunzip -c "$SYSTEM_BACKUP" | mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD"

if [ $? -ne 0 ]; then
    echo "❌ Error: System database restore failed"
    exit 1
fi

echo "✅ System database restored successfully"

# Restore each tenant database
for TENANT_BACKUP in $TENANT_BACKUPS; do
    DB_NAME=$(basename "$TENANT_BACKUP" | sed "s/mariadb_\(.*\)_$TIMESTAMP\.sql\.gz/\1/")
    echo "Restoring tenant database '$DB_NAME' from $(basename "$TENANT_BACKUP")..."
    
    gunzip -c "$TENANT_BACKUP" | mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD"
    
    if [ $? -ne 0 ]; then
        echo "❌ Error: Tenant database '$DB_NAME' restore failed"
        exit 1
    fi
    
    echo "✅ Tenant database '$DB_NAME' restored successfully"
done

echo ""
echo "🎉 All databases restored successfully from timestamp $TIMESTAMP!"