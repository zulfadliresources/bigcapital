#!/bin/bash

# Manual restore script for MySQL backups
# Restores from a compressed .sql.gz backup file

# Configuration - set these environment variables or modify here
DB_HOST=${DB_HOST:-mysql}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}

# Check if backup file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_file.sql.gz>"
    echo "Example: $0 /host-backups/mysql_20251126_113855.sql.gz"
    exit 1
fi

BACKUP_FILE=$1

# Check if file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file '$BACKUP_FILE' not found"
    exit 1
fi

echo "Starting MySQL restore..."
echo "Host: $DB_HOST"
echo "File: $BACKUP_FILE"

# Confirm before restore
read -p "This will overwrite existing databases. Are you sure? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 0
fi

# Perform restore
echo "Restoring from $BACKUP_FILE..."
gunzip -c "$BACKUP_FILE" | mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD"

if [ $? -eq 0 ]; then
    echo "Restore completed successfully from $BACKUP_FILE"
else
    echo "Error: Restore failed"
    exit 1
fi