# Backup Service Fix

## Issues Fixed

### 1. ✅ File Ownership (root:root → zulfa5798:almalinux)
- **Problem**: Backup files were created as `root:root` instead of `zulfa5798:almalinux`
- **Fix**: 
  - Properly detect host directory UID/GID using `stat`
  - Create user/group with matching IDs
  - Force `chown` after every file creation
  - Set explicit file permissions (644)

### 2. ✅ Old Files Not Deleted + Smart Deduplication
- **Problem**: Files older than 7 days weren't being cleaned up; hourly backups were spamming storage (120 files/day)
- **Fix**:
  - Properly export environment variables to `/etc/backup-env`
  - Backup script now sources env file before running
  - **Date-based cleanup** (not `-mtime`) — reads date from filename (`YYYYMMDD`) so `ctime` resets don't interfere
  - **Deduplication**: For previous days within retention window, only the **latest run** of the day is kept; today's hourly files are all kept
  - Result: ~5 files × 6 previous days + today's hourly files (was 875 files → ~74)

### 3. ✅ Better Logging & Visibility
- Added comprehensive logging with:
  - File sizes and permissions verification
  - Before/after cleanup counts
  - Total disk usage
  - Success/failure indicators (✓/✗)

## How to Apply

### Step 1: Restart the backup service
```bash
# Stop the current backup container
docker stop bigcapital-backup
docker rm bigcapital-backup

# Restart with the fixed configuration
docker-compose -f docker-compose-zrprod-ghcr-hostdb.yml -f docker-compose-zrprod-ghcr-hostdb.vps.yml up -d backup
```

### Step 2: Verify the fix
```bash
# Check the backup service logs (should run initial test backup)
docker logs bigcapital-backup

# Wait for first backup to complete, then check ownership
ls -lh /home/zulfadli.com/backups/bigcapital/

# Should show: -rw-r--r-- 1 zulfa5798 almalinux [size] [date] [filename]
```

### Step 3: Fix existing files (optional)
```bash
# Fix ownership of all existing backup files
sudo chown -R zulfa5798:almalinux /home/zulfadli.com/backups/bigcapital/
```

### Step 4: Run manual backup (triggers deduplication immediately)
```bash
docker exec bigcapital-backup /usr/local/bin/backup.sh

# Check result
for FILE in /home/zulfadli.com/backups/bigcapital/*.gz; do basename "$FILE" | grep -oE '[0-9]{8}_[0-9]{6}' | cut -d'_' -f1; done | sort | uniq -c
```

## Useful Commands

```bash
# Run manual backup (tests the script immediately)
docker exec bigcapital-backup /usr/local/bin/backup.sh

# View backup logs
docker exec bigcapital-backup cat /backups/cron.log

# View today's backup log
docker exec bigcapital-backup cat /backups/backup_$(date +%Y%m%d).log

# Check environment variables
docker exec bigcapital-backup cat /etc/backup-env

# Check disk usage
du -sh /home/zulfadli.com/backups/bigcapital/
df -h /home/zulfadli.com/backups/

# List all backups with details
ls -lht /home/zulfadli.com/backups/bigcapital/ | head -20
```

## Backup Schedule

- **Cron**: Every hour at :17 (e.g., 00:17, 01:17, 02:17...)
- **Retention**: 7 days (configurable via `BACKUP_RETENTION_DAYS`)
- **Location**: `/home/zulfadli.com/backups/bigcapital/`

## Deduplication Strategy

| Day | Files Kept |
|-----|------------|
| Today | All hourly runs |
| Previous days (within 7 days) | Latest run only (1 run × N databases) |
| Older than 7 days | Deleted |

**Expected file count**: ~5 files × 6 previous days + today's hourly files

## What Gets Backed Up

1. **MariaDB System DB**: `mariadb_bigcapital_system_TIMESTAMP.sql.gz`
2. **MariaDB Tenant DBs**: `mariadb_bigcapital_<name>_TIMESTAMP.sql.gz`
3. **MongoDB**: disabled (not in use yet — uncomment in `docker-compose-zrprod-ghcr-hostdb.vps.yml` to re-enable)

## Monitoring

The backup script now logs:
- ✓ Success indicator for each backup
- ✗ Failure indicator if backup fails
- File size and ownership after creation
- Number of files deleted during cleanup
- Total disk usage

Check logs regularly:
```bash
docker logs bigcapital-backup --tail 100 -f
```
