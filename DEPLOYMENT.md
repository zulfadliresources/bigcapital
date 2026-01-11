# BigCapital Deployment Guide

## Local Development (MacBook)

**Simple auto-login mode** - phpMyAdmin accessible without authentication.

```bash
# Start all services
docker-compose -f docker-compose-zrprod-ghcr.yml up -d
# 
docker-compose -f docker-compose.zr.local.yml down
docker-compose -f docker-compose.zr.local.yml down && docker volume rm bigcapital_mariadb-local && docker volume rm bigcapital_redis-local 

docker-compose -f docker-compose.zr.local.yml up -d --pull always

docker-compose -f docker-compose.zr.local.yml up -d


docker-compose -f docker-compose.zr.local.yml logs server --tail 20

docker-compose -f docker-compose.zr.local.yml restart server

# Access BigCapital
http://localhost:8080

# Access phpMyAdmin (auto-login)
http://localhost:8081
```

**Features:**
- ✅ phpMyAdmin auto-login with DB credentials
- ✅ Bound to `127.0.0.1` (localhost only)
- ✅ Not accessible from network
- ✅ Fast development workflow

---

## VPS Production Deployment

**Secure mode** - phpMyAdmin requires MySQL authentication and SSH tunnel.

### Via Docker CLI

```bash
# Start with VPS security overrides
docker-compose \
  -f docker-compose-zrprod-ghcr.yml \
  -f docker-compose-zrprod-ghcr.vps.yml \
  up -d
```

### Via Portainer

1. **Stack Name:** `bigcapital`
2. **Upload files:**
   - `docker-compose-zrprod-ghcr.yml`
   - `docker-compose-zrprod-ghcr.vps.yml`
3. **Build method:** Repository (or paste YAML)
4. **Environment variables:** Upload `.env` file

**Access BigCapital:**
```
http://your-domain.com
```

**Access phpMyAdmin (SSH tunnel required):**
```bash
# On your local machine
ssh -L 8081:localhost:8081 user@your-vps-ip

# Then browse to:
http://localhost:8081

# Login with MySQL credentials:
Username: bigcapital (or as per your .env)
Password: [your DB_PASSWORD]
```

**Features:**
- ✅ phpMyAdmin requires MySQL authentication
- ✅ No public port exposure
- ✅ SSH tunnel required for access
- ✅ Cookie-based auth with session timeout
- ✅ Production-grade security

---

## Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Database
DB_USER=bigcapital
DB_PASSWORD=your_secure_password
DB_HOST=mysql

# Application
BASE_URL=http://localhost:8080  # or https://your-domain.com
JWT_SECRET=your_jwt_secret_here

# Mail settings
MAIL_HOST=smtp.gmail.com
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password
```

---

## Security Notes

### Local Development
- phpMyAdmin bound to `127.0.0.1` (not accessible from network)
- Auto-login enabled for convenience
- Safe for local-only use

### VPS Production
- phpMyAdmin **not exposed** on public ports
- Requires SSH tunnel + MySQL credentials
- Cookie authentication with automatic logout
- Use strong `DB_PASSWORD` in production

---

## Backup Service

Automated daily backups at 2:17 AM (cron schedule: `17 * * * *`):

```bash
# Manual backup
docker exec bigcapital-backup /usr/local/bin/backup.sh

# Check backup logs
docker logs bigcapital-backup

# View cron logs
docker exec bigcapital-backup tail -f /backups/cron.log
```

**Backup Locations:**
- Inside container: `/backups/` (MySQL `.sql.gz` and MongoDB `.archive.gz` files)
- Host: `./backups/` (automatically copied from container)

**Backup Files:**
- MySQL: `mysql_YYYYMMDD_HHMMSS.sql.gz` (contains all databases)
- MongoDB: `mongo_YYYYMMDD_HHMMSS.archive.gz` (bigcapital database)

Retention: 7 days (old backups auto-deleted)

---

## Restore Backups

### Restore MySQL Backup

Use the provided restore script (requires confirmation):

```bash
# From the backups directory
cd backups
./restore_mysql.sh mysql_YYYYMMDD_HHMMSS.sql.gz
```

Or restore directly via container:

```bash
# Restore latest MySQL backup
docker exec bigcapital-backup sh -c "gunzip -c /host-backups/mysql_$(ls -t /host-backups/mysql_*.sql.gz | head -1 | xargs basename) | mysql -hmysql -u$DB_USER -p$DB_PASSWORD"
```

### Restore MongoDB Backup

```bash
# Restore latest MongoDB backup
docker exec bigcapital-mongo mongorestore --archive=/host-backups/$(ls -t /host-backups/mongo_*.archive.gz | head -1 | xargs basename) --db=bigcapital --drop
```

**Note:** Restoring will overwrite existing data. Always backup current data first if needed.

---

## Troubleshooting

### phpMyAdmin not accessible on VPS
1. Verify SSH tunnel is active: `ssh -L 8081:localhost:8081 user@vps`
2. Check container: `docker ps | grep phpmyadmin`
3. Check logs: `docker logs bigcapital-phpmyadmin`

### Database connection errors
1. Check credentials in `.env`
2. Verify MySQL is running: `docker ps | grep mysql`
3. Check permissions: `docker logs bigcapital-mysql-permissions`

### Application not loading
1. Check Envoy proxy: `docker logs bigcapital-proxy-1`
2. Verify containers: `docker-compose -f docker-compose-zrprod-ghcr.yml ps`
3. Check server logs: `docker logs bigcapital-server`
