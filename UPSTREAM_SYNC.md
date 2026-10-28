# Syncing with upstream — keep list

Everything this fork changes on purpose, and the exact steps to update from
`upstream/develop` without losing them or re-debugging the same failures.

Read this before running `git merge develop`.

---

## 1. Ground rules

| Item | Value |
|---|---|
| Fork remote | `origin` → `https://github.com/zulfadliresources/bigcapital.git` |
| Upstream remote | `upstream` → `https://github.com/bigcapitalhq/bigcapital.git` |
| Working branch | `ghcrlocal` |
| Upstream branch to merge | `develop` (never `main`) |
| Deploy target | Portainer stack `bigcapital` (local dev **and** VPS) |
| Images | `ghcr.io/zulfadliresources/bigcapital/{webapp,server,migration}` |

The fork must keep **16 files** different from `develop`. Everything else comes
from upstream.

```bash
# Show exactly what we diverge on. Should list the same 16 files as §2.
git diff --name-only develop HEAD
```

If that list grows, something was changed that is not documented here — check
whether it belongs in §2 or should be reverted to upstream.

---

## 2. Files we must keep (16)

### 2.1 Local-only — do not exist upstream

| File | Purpose |
|---|---|
| `.github/workflows/publish-zr-images.yml` | Builds and pushes the three images to GHCR on push to `ghcrlocal` |
| `scripts/publish-zr-images.sh` | Same build, from a workstation (streams `git archive` into Docker) |
| `docker-compose-zrprod-ghcr-hostdb.yml` | **Main stack.** Host MariaDB + host Redis; used for local dev and VPS |
| `docker-compose-zrprod-ghcr-hostdb.vps.yml` | VPS overlay: host backup path, retention, cron schedule |
| `docker-compose-zrprod-ghcr.yml` | Self-contained variant (bundled MariaDB/Redis) |
| `docker-compose-zrprod-ghcr.vps.yml` | VPS overlay for the self-contained variant |
| `docker-compose-zrprod-ghcr_old.yml` | Archive of the previous stack; unused |
| `docker-compose.zr.local.yml` | Early local-only compose; unused by the current stack |
| `backups/manual_backup.sh` | Ad-hoc dump helper |
| `backups/restore_mysql.sh` | Restore helper |
| `DEPLOYMENT.md` | Rewritten for the hostdb stack |
| `BACKUP_FIX_README.md` | Notes on the backup permission fixes |

### 2.2 Modified upstream files — must not be reverted

| File | What we changed | Why |
|---|---|---|
| `packages/server/src/modules/Tenancy/TenancyDB/TenancyDB.module.ts` | Read `tenantDatabase.dbNamePrefix` instead of hardcoding `bigcapital_tenant_` | **Upstream bug.** Without it every tenant query fails with `ER_BAD_DB_ERROR` when `TENANT_DB_NAME_PERFIX` is not `bigcapital_tenant_` |
| `docker/migration/Dockerfile` | `ARG SERVER_IMAGE` base + `nc` poll on `SYSTEM_DB_HOST`/`DB_HOST` instead of `wait-for-it.sh mysql:3306` | The hardcoded `mysql` hostname does not exist in the hostdb stack, and the CLI path differs from the registry image |
| `.gitignore` | Added `.env.zr.local`, `/backups/*.sql.gz`, `/backups/*.gz` | Keep secrets and dumps out of git |
| `packages/webapp/nginx/sites/default.conf` | Added `location /api` proxy to `server:3000` | Webapp image runs without the Envoy proxy in simpler setups |
| `vercel.json` | `outputDirectory: packages/webapp/dist` | Develop moved CRA → Vite; the old value `build` no longer exists |

### 2.3 Runtime config that must survive in the compose files

These are the boot blockers that cost hours. Verify each one after a merge.

| Setting | Correct value | Failure if wrong |
|---|---|---|
| `APP_JWT_SECRET` | `${APP_JWT_SECRET:?...}` | Server throws on startup: `APP_JWT_SECRET is not configured` |
| `S3_BUCKET` | `${S3_BUCKET:-bigcapital}` | Server crashes: `Error: bucket is required` |
| `GOTENBERG_URL` | `http://gotenberg:3000` | PDF generation fails; the image listens on 3000, not 9003 |
| `GOTENBERG_DOCS_URL` | `http://server:3000/public/` | PDF render fetches the wrong origin |
| `QUEUE_HOST` / `QUEUE_PORT` | Same host/port as Redis | BullMQ defaults to `localhost` inside the container |
| `TENANT_DB_NAME_PERFIX` | `${TENANT_DB_NAME_PREFIX}` | Tenant DB name mismatch (see §2.2 first row) |
| `extra_hosts` | `host.docker.internal:host-gateway` | Containers cannot reach host MariaDB/Redis |
| image refs | `${ZR_IMAGE_REGISTRY:-ghcr.io/zulfadliresources/bigcapital}/...` | Wrong namespace → `denied` on pull, stack ends up with zero containers |

Note the spelling: the code reads `TENANT_DB_NAME_PERFIX` (upstream typo).
Keep it. Do not "fix" it to `PREFIX` — nothing reads that name.

---

## 3. Sync procedure

### 3.1 Before you start

```bash
git status                     # must be clean
git switch ghcrlocal
git fetch upstream --tags --prune
git fetch origin --prune
```

Create a safety point:

```bash
git branch ghcrlocal-backup-$(date +%Y%m%d) ghcrlocal
git tag  pre-upstream-$(date +%Y%m%d) ghcrlocal
```

### 3.2 Merge

```bash
git merge upstream/develop
```

Expect conflicts in `packages/{server,webapp}` and possibly `.gitignore`.
Resolve in favour of upstream for everything **except** the 16 files in §2:

```bash
# 1. Take upstream for all conflicted files...
git checkout --theirs -- $(git diff --name-only --diff-filter=U)

# 2. ...then restore our 16 files from the backup branch.
git checkout <backup-branch> -- \
  .github/workflows/publish-zr-images.yml \
  scripts/publish-zr-images.sh \
  .gitignore \
  vercel.json \
  DEPLOYMENT.md \
  BACKUP_FIX_README.md \
  backups \
  docker-compose.zrprod-ghcr-hostdb.yml \
  docker-compose.zrprod-ghcr-hostdb.vps.yml \
  docker-compose.zrprod-ghcr.yml \
  docker-compose.zrprod-ghcr.vps.yml \
  docker-compose.zrprod-ghcr_old.yml \
  docker-compose.zr.local.yml \
  docker/migration/Dockerfile \
  packages/webapp/nginx/sites/default.conf \
  packages/server/src/modules/Tenancy/TenancyDB/TenancyDB.module.ts

git add -A
git commit -F - <<'MSG'
chore: merge upstream develop, keep ZR deployment config
MSG
```

For the two files where upstream may have genuinely improved something
(`TenancyDB.module.ts`, `docker/migration/Dockerfile`), diff before deciding:

```bash
git diff develop HEAD -- packages/server/src/modules/Tenancy/TenancyDB/TenancyDB.module.ts
git diff develop HEAD -- docker/migration/Dockerfile
```

If upstream fixed the prefix bug themselves, drop our patch. Do not carry a
patch that upstream already made.

### 3.3 Verify the merge

```bash
# Should be exactly the 16 files from §2.
git diff --name-only develop HEAD

# Compose must still resolve.
docker compose -f docker-compose-zrprod-ghcr-hostdb.yml config > /dev/null && echo OK

# The four critical env keys must still be present.
grep -nE 'APP_JWT_SECRET|S3_BUCKET|QUEUE_HOST|GOTENBERG_URL' \
  docker-compose-zrprod-ghcr-hostdb.yml
```

---

## 4. Build and publish

CI is the supported path: pushing to `ghcrlocal` triggers
`.github/workflows/publish-zr-images.yml`, which builds webapp + server on
`linux/amd64,linux/arm64` and then the migration image on top of the new server
tag.

```bash
git push origin ghcrlocal
```

Watch it:

```bash
curl -s "https://api.github.com/repos/zulfadliresources/bigcapital/actions/runs?per_page=1" \
  | python3 -c "import json,sys; r=json.load(sys.stdin)['workflow_runs'][0]; print(r['head_sha'][:7], r['status'], r['conclusion'])"
```

Local fallback (no CI):

```bash
GHCR_USER=zulfadliresources GHCR_TOKEN=<pat-with-write:packages> \
  ./scripts/publish-zr-images.sh

# build only
./scripts/publish-zr-images.sh --no-push
ZR_TAG=verify ./scripts/publish-zr-images.sh --no-push   # custom tag
```

### Why the script streams `git archive` instead of `docker build .`

The repo contains **two directories that differ only by letter case**:

```
packages/server/src/modules/ee   →  23 files  (Workspaces)
packages/server/src/modules/EE   →  52 files  (AuditLogs, BillLandedCosts, EE.module.ts)
```

Linux keeps both. macOS (APFS, case-insensitive) merges them into a single
`EE` directory, so `import ... from '../ee/Workspaces/...'` fails with:

```
error TS2307: Cannot find module '../ee/Workspaces/Workspaces.module'
```

`git archive HEAD | docker build -` hands Docker the real tree, so local builds
behave like CI. Never build with a plain working-tree context on macOS.

This also means: **a local `pnpm run dev:server` may hit the same TS2307.** If it
does, that is the cause, not your change.

---

## 5. Deploy

Portainer → stack `bigcapital` → **Pull and redeploy**.

Compose paths:

```
docker-compose-zrprod-ghcr-hostdb.yml, docker-compose-zrprod-ghcr-hostdb.vps.yml
```

Stack environment variables that must exist:

```
APP_JWT_SECRET=<openssl rand -base64 48>
DB_USER=<mariadb user>
DB_PASSWORD=<mariadb password>
DB_HOST=host.docker.internal
DB_CHARSET=utf8
SYSTEM_DB_NAME=bigcapital_system
TENANT_DB_NAME_PREFIX=bigcapital_
S3_BUCKET=bigcapital
S3_REGION=US
REDIS_HOST=host.docker.internal
REDIS_PORT=6379
```

Optional image pinning:

```
ZR_IMAGE_REGISTRY=ghcr.io/zulfadliresources/bigcapital
ZR_IMAGE_TAG=latest        # or a commit sha / ghcrlocal
```

Host prerequisites: MariaDB on `:3306` and Redis on `:6379`, both listening on
`0.0.0.0` (not `127.0.0.1` only), so containers can reach them through
`host.docker.internal`.

---

## 6. Post-deploy checklist

```bash
docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | grep bigcapital
```

Expected:

| Container | Expected |
|---|---|
| `bigcapital-server` | `Up (healthy)` |
| `bigcapital-webapp` | `Up` |
| `bigcapital-database-migration` | `Exited (0)` |
| `bigcapital-proxy-1` | `Up` |
| `bigcapital-mongo` | `Up` |
| `bigcapital-gotenberg-1` | `Up` |
| `bigcapital-backup` | `Up` |

Endpoints:

```bash
curl -s -o /dev/null -w 'api=%{http_code}\n'    http://localhost:8080/api/system_db   # 200
curl -s -o /dev/null -w 'webapp=%{http_code}\n' http://localhost:8080/                 # 200
```

Login and tenant access (the tenant header is required — a bare Bearer token
returns `401 Organization ID is required`):

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/signin \
  -H 'Content-Type: application/json' \
  -d '{"email":"<email>","password":"<password>"}' \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['access_token'])")

for p in dashboard/boot accounts items customers; do
  printf '%-16s ' "$p"
  curl -s -o /dev/null -w '%{http_code}\n' \
    -H "Authorization: Bearer $TOKEN" -H "organization-id: <orgSlug>" \
    "http://localhost:8080/api/$p"
done
```

All should be 200. The login route is `/api/auth/signin`, **not** `/api/auth/login`.

---

## 7. Known failure modes

### 7.1 `ER_BAD_DB_ERROR: Unknown database 'bigcapital_tenant_<org>'`

Server is looking in the wrong tenant database.

```bash
docker logs bigcapital-server 2>&1 | grep ER_BAD_DB
```

Cause: `TENANT_DB_NAME_PERFIX` is missing or the `TenancyDB.module.ts` patch in
§2.2 was reverted during a merge. The prefix must reach
`tenantDatabase.dbNamePrefix`.

### 7.2 `The migration directory is corrupt, the following files are missing: ...*.ts`

The DB records migration filenames with `.ts`, but images ship compiled `.js`.
Seen on databases first created by an old image.

Back up first, then fix the metadata only:

```bash
mysqldump -h 127.0.0.1 -P 3306 -u <user> -p<pass> <tenant_db> knex_migrations \
  > /tmp/knex_migrations_backup.sql

# confirm what is affected
mysql -h 127.0.0.1 -P 3306 -u <user> -p<pass> <tenant_db> \
  -e "SELECT id,name FROM knex_migrations WHERE name LIKE '%.ts';"

# rewrite the recorded names
mysql  -h 127.0.0.1 -P 3306 -u <user> -p<pass> <tenant_db> \
  -e "UPDATE knex_migrations SET name = REPLACE(name,'.ts','.js') WHERE name LIKE '%.ts';"

docker start bigcapital-database-migration
docker logs bigcapital-database-migration
```

Expected tail: `All tenants are migrated.` and exit code `0`.

### 7.3 `Error: bucket is required`

`S3_BUCKET` was empty. The compose default (`bigcapital`) must survive merges.

### 7.4 `APP_JWT_SECRET is not configured`

Rename regressed to `JWT_SECRET`. The current server only reads
`APP_JWT_SECRET`.

### 7.5 Stack has no containers / images fail to pull

1. `docker manifest inspect ghcr.io/zulfadliresources/bigcapital/server:latest`
2. `denied` → package private, or the compose still points at
   `ghcr.io/bigcapitalhq/*` (that namespace no longer serves these images).
3. Check what the stack resolves: `docker compose ... config | grep image:`

### 7.6 Workflow pushed but no run was created

GitHub Actions was disabled for the repository. Verify:

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  https://github.com/zulfadliresources/bigcapital/actions      # 404 = disabled
```

Settings → Actions → General:
- Enable Actions.
- Permission: **Allow zulfadliresources, and select non-zulfadliresources**.
- Check **Allow actions created by GitHub** (covers `actions/checkout`).
- Allowed list: `docker/*`.

Do **not** choose "Allow zulfadliresources actions only" — the workflow uses
`actions/checkout`, `docker/setup-buildx-action`, `docker/login-action`,
`docker/build-push-action`, and every one of them would be blocked.

A push made while Actions is disabled produces no run at all; touch the
workflow file to trigger registration after enabling.

### 7.7 `TS2307: Cannot find module '../ee/Workspaces/...'`

macOS merged `ee/` and `EE/`. Build with `git archive` (§4). Do not "fix" it by
renaming upstream directories — that reintroduces the conflict on every sync.

---

## 8. What we deliberately dropped

These were local edits that the first merge discarded, on purpose: they were
older copies of files upstream had since improved (permission guards, bulk
delete, ledger, EE modules).

| Area | Upstream behaviour now in effect |
|---|---|
| `Vendors/Accounts/Bills/...controllers` | `@UseGuards(AuthorizationGuard, PermissionGuard)` + `@RequirePermission(...)` restored |
| `Delete*.service.ts` | Accept `trx?: Knex.Transaction` again |
| `webapp/src/store/*` | `.tsx` → `.ts`, directory names lowercased (`Bills/` → `bills/`) |
| `containers/Alerts/*BulkDeleteAlert.tsx` | Removed upstream; do not resurrect |
| `webapp` build | CRA/`craco` → Vite (`dist`, not `build`) |

If any of these turned out to be needed, restore it as a *documented* divergence
and add it to §2 — do not patch silently.

---

## 9. Quick reference

```bash
# divergence from upstream (expect 16 files)
git diff --name-only develop HEAD

# upstream commits not yet merged
git rev-list --count HEAD..develop

# safety point
git branch ghcrlocal-backup-$(date +%Y%m%d) ghcrlocal

# merge, keeping our files
git merge upstream/develop
git checkout <backup> -- <the 16 files>
git add -A && git commit

# publish
git push origin ghcrlocal

# deploy
# Portainer -> bigcapital -> Pull and redeploy

# verify
docker ps -a --format '{{.Names}}\t{{.Status}}' | grep bigcapital
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/api/system_db
```
