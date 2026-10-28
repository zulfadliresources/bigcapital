# BigCapital Deployment Guide

## Overview: which compose file to use

| File | Database | Redis | Use when |
|---|---|---|---|
| `docker-compose-zrprod-ghcr-hostdb.yml` | host MariaDB | host Redis | Local dev **and** VPS where MariaDB/Redis already run on the host |
| `docker-compose-zrprod-ghcr.yml` | bundled MariaDB | bundled Redis | Self-contained stack, nothing on the host |
| `docker-compose-zrprod-ghcr-hostdb.vps.yml` | override for the hostdb file | — | Adds VPS backup paths (see VPS section) |

The host-database variants reach the host over `host.docker.internal`, mapped
with `extra_hosts: host.docker.internal:host-gateway` so it works on both
Docker Desktop and Linux servers.

---

## Image publishing

The stack pulls images from `ghcr.io/zulfadliresources/bigcapital/*`. Build and
push them from this repository — the stack never builds from source.

```bash
# Build all three images and push :ghcrlocal + :latest
./scripts/publish-zr-images.sh

# Build only, no registry login/push
./scripts/publish-zr-images.sh --no-push

# Custom tag
ZR_TAG=v1.2.3 ./scripts/publish-zr-images.sh
```

Requires a GitHub PAT with `write:packages` scope:

```bash
export GHCR_USER=zulfadliresources
export GHCR_TOKEN=<your_pat>
./scripts/publish-zr-images.sh
```

The script streams `git archive HEAD` into the build. Do **not** build with a
plain `docker build .`: the repo has both `modules/ee` and `modules/EE`, and
macOS merges them into one directory, which fails the TypeScript build.

> GitHub Actions is currently disabled on the fork, so the CI workflow
> `.github/workflows/publish-zr-images.yml` does not run. Enable it under
> Settings → Actions → General, or publish from your machine with the script.

After pushing, make the packages public if Portainer runs without registry
credentials: GitHub → your profile → Packages → each package → Change
visibility.

---

## Configuration

Every value the stack needs lives in the environment. For local dev copy:

```bash
cp .env.example .env.zr.local
```

Required values that abort startup when wrong:

| Variable | Why |
|---|---|
| `APP_JWT_SECRET` | The server refuses to start without it (`openssl rand -base64 48`). |
| `S3_BUCKET` | Empty bucket aborts startup with `bucket is required`. Defaults to `bigcapital`. |
| `DB_HOST` / `DB_USER` / `DB_PASSWORD` | Host MariaDB credentials. |
| `SYSTEM_DB_NAME` | System database name, usually `bigcapital_system`. |
| `TENANT_DB_NAME_PREFIX` | Tenant database prefix, usually `bigcapital_`. |

`REDIS_HOST` and `REDIS_PORT` are reused for `QUEUE_HOST` / `QUEUE_PORT`
automatically; set the `QUEUE_*` pair only if the queue lives elsewhere.

Optional image pinning (set in Portainer → stack → Environment variables):

```
ZR_IMAGE_REGISTRY=ghcr.io/zulfadliresources/bigcapital
ZR_IMAGE_TAG=ghcrlocal        # omit to use :latest
```

---

## Local Development (MacBook)

Assumes MariaDB and Redis already run on the host (ports 3306 and 6379).

```bash
# ghcr-hostdb (host MariaDB + host Redis)
docker-compose -f docker-compose-zrprod-ghcr-hostdb.yml --env-file .env up -d

# Follow the server log
docker-compose -f docker-compose-zrprod-ghcr-hostdb.yml logs -f server

# Stop
docker-compose -f docker-compose-zrprod-ghcr-hostdb.yml down


# Access BigCapital (HTTP via Envoy proxy)
http://localhost:8080

# HTTPS (self-signed certificate)
https://localhost:8443

# phpMyAdmin is NOT part of the hostdb stack. Use a local client such as
# TablePlus/DBeaver against 127.0.0.1:3306, or add a phpMyAdmin service
# yourself if you want one.
```

**Notes:**
- ✅ No database container: MariaDB and Redis come from the host
- ✅ Backups write to the host path configured in the VPS override
- ✅ Same compose file for local dev and VPS (only the override differs)
- ✅ Fast development workflow

---

## VPS Production Deployment

Same stack as local dev: MariaDB and Redis run on the host, containers reach
them through `host.docker.internal`.

### Via Docker CLI

```bash
# Base stack
docker-compose -f docker-compose-zrprod-ghcr-hostdb.yml --env-file .env up -d

# With VPS backup overrides (host backup paths, retention, cron schedule)
docker-compose \
  -f docker-compose-zrprod-ghcr-hostdb.yml \
  -f docker-compose-zrprod-ghcr-hostdb.vps.yml \
  --env-file .env up -d
```

### Via Portainer

1. **Stack Name:** `bigcapital`
2. **Repository:** `https://github.com/zulfadliresources/bigcapital.git`
3. **Compose path:**
   ```
   docker-compose-zrprod-ghcr-hostdb.yml, docker-compose-zrprod-ghcr-hostdb.vps.yml
   ```
4. **Environment variables:** add the contents of your `.env`

**Access BigCapital:**
```
http://your-domain.com
```

**Backups** (after the VPS override):

```bash
# Host path
ls -lh /home/zulfadli.com/backups/bigcapital/

# Trigger a backup now
docker exec bigcapital-backup /usr/local/bin/backup.sh

# Follow the schedule log
docker exec bigcapital-backup cat /backups/cron.log
```

Retention is controlled by `BACKUP_RETENTION_DAYS` (default 7). The schedule
is `17 * * * *` — hourly at minute 17.

---

## Security Notes

- The stack publishes only the Envoy proxy ports (8080/8443 by default). Server,
  webapp, Mongo and Gotenberg stay on the internal network via `expose`.
- MariaDB and Redis are **not** containerised here. They are reachable on the
  host, so their own authentication and firewall rules are what protect them.
- Keep `APP_JWT_SECRET` and `DB_PASSWORD` out of git. `.env` and `.env.zr.local`
  are ignored.
- `GOTENBERG_DOCS_URL` points at `http://server:3000/public/`; make sure that
  path stays reachable only inside the stack network.
- Cookie authentication with automatic logout
- Use strong `DB_PASSWORD` in production

---

## Backup Service

Hourly backups at minute 17 (cron schedule: `17 * * * *`):

```bash
# Manual backup
docker exec bigcapital-backup /usr/local/bin/backup.sh

# Check backup logs
docker logs bigcapital-backup

# View cron logs
docker exec bigcapital-backup tail -f /backups/cron.log
```

**Backup Locations:**
- Inside container: `/backups/` (cron log)
- Host: `/home/zulfadli.com/backups/bigcapital/` (from the VPS override)

**Backup Files** (written to the host path from the VPS override):

- `mariadb_bigcapital_system_YYYYMMDD_HHMMSS.sql.gz` — system database
- `mariadb_bigcapital_tenant_<id>_YYYYMMDD_HHMMSS.sql.gz` — one per tenant

Retention: `BACKUP_RETENTION_DAYS` (default 7). All runs from today are kept;
for previous days only the latest run is kept.

---

## Restore Backups

### Restore MySQL Backup

Use the bundled restore script (requires confirmation):

```bash
cd backups
./restore_mysql.sh /home/zulfadli.com/backups/bigcapital/mariadb_bigcapital_system_YYYYMMDD_HHMMSS.sql.gz
```

**Note:** Restoring overwrites existing data. Take a fresh backup before you
start.

---

## Troubleshooting

### Stack has no containers / images fail to pull
1. Confirm the image exists: `docker manifest inspect ghcr.io/zulfadliresources/bigcapital/server:latest`
2. If it returns `denied`, the GHCR package is private — either make it public
   or add a registry credential in Portainer.
3. Check which tag the stack resolves: `docker compose -f docker-compose-zrprod-ghcr-hostdb.yml config | grep image:`

### Server exits with "APP_JWT_SECRET is not configured"
Set `APP_JWT_SECRET` in the stack environment (`openssl rand -base64 48`).

### Server exits with "bucket is required"
`S3_BUCKET` was empty. Leave the compose default (`bigcapital`) or set it.

### Database connection errors
1. Check the credentials in `.env`.
2. Verify MariaDB listens on the host: `nc -z 127.0.0.1 3306`.
3. From inside a container: `docker run --rm --add-host=host.docker.internal:host-gateway alpine nc -z host.docker.internal 3306`.
4. On Linux, `host.docker.internal` needs Docker 20.10+ (provided by
   `extra_hosts: host-gateway`).

### Application not loading
1. Check the proxy: `docker logs bigcapital-proxy` (or the stack's proxy container).
2. List stack containers: `docker compose -f docker-compose-zrprod-ghcr-hostdb.yml ps`.
3. Check the server: `docker logs bigcapital-server`.
4. Run migrations manually: `docker compose -f docker-compose-zrprod-ghcr-hostdb.yml run --rm database_migration`.
