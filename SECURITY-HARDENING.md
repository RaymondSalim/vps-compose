# Security hardening guide

Production-focused security documentation for the `vps-compose` repository on a single OVHcloud VPS (Debian 12, Docker Engine, host-level Caddy).

## 1. Architecture and trust boundaries

```
Internet
   |
   +-- :443  Caddy (host) --> 127.0.0.1:3012 Cronicle (admin job runner)
   |
   +-- :5432  Docker publish --> PostgreSQL (vercel role / micasa-prod only via pg_hba)
   |
   +-- :25565  Minecraft (optional, separate Compose project)

Docker networks:
  db_internal (internal:true)  -- PostgreSQL
  backup_egress                -- backup container outbound to S3
  cronicle_net                 -- Cronicle only
  minecraft_net                -- Minecraft only (when deployed)
```

Trust boundaries:

| Zone | Components | Trust level |
|------|------------|-------------|
| Internet | Vercel, operators, attackers | Untrusted |
| Host | Caddy, SSH, UFW, Docker Engine | Admin trust |
| `db_internal` | PostgreSQL, backup (DB leg) | Data plane |
| `backup_egress` | backup (S3 leg) | Controlled egress |
| `cronicle_net` | Cronicle | High-impact admin |

## 2. Public port inventory

| Port | Bind address | Service | Intended exposure |
|------|--------------|---------|-------------------|
| 443 | 0.0.0.0 (Caddy host) | HTTPS reverse proxy | Public |
| 5432 | 0.0.0.0 (Docker) | PostgreSQL | Public (Vercel); restricted by `pg_hba.conf` |
| 3012 | 127.0.0.1 only | Cronicle | Localhost only; public via Caddy |
| 25565 | 0.0.0.0 (if deployed) | Minecraft | Public (whitelisted) |

## 3. Residual risks

1. **PostgreSQL plaintext transport.** SCRAM protects passwords on the wire; query data is not encrypted. Vercel-to-VPS traffic can be observed on the network path.
2. **PostgreSQL Internet reachability.** Vercel serverless egress is not assumed to have fixed IPs, so IP allowlisting at the firewall is not used. Protection relies on `pg_hba.conf` role/database rules and strong credentials.
3. **Cronicle is Internet-facing** (via Caddy). Compromise grants remote job execution. Mitigations: Caddy basic auth, Cronicle auth, localhost bind, no Docker socket, capability dropping.
4. **Docker bypasses UFW** for published ports. Use explicit bind addresses and host `iptables`/`DOCKER-USER` chain if additional filtering is required.
5. **Secrets in container environment** (Cronicle SMTP/HMS) remain visible to root on the host via `docker inspect`. Prefer file-based secrets for new services.
6. **Backup container runs as root** because Alpine `cronie` requires root for `/etc/crontabs/root`. Secrets are file-mounted, not embedded in crontab.
7. **Git history** may contain old patterns (placeholder passwords in examples). Rotating production credentials is required if real secrets were ever committed.

## 4. Secret management procedure

1. Never commit `.env`, `secrets/pgpass`, `secrets/aws_credentials`, or TLS private keys.
2. On the VPS, create secret files with mode `0600` and directory mode `0700`.
3. Rotate in this order when compromised: application DB password (`vercel`), backup role password, AWS IAM keys, Cronicle/HMS/SMTP secrets, PostgreSQL superuser password.
4. Updating secrets does not remove them from Git history. Use `git log -p` to audit; rotate credentials after any leak.
5. `docker inspect` shows environment variables; treat container env as sensitive.

### Backup secrets layout

`secrets/pgpass` (one line):

```
database:5432:micasa-prod:backup:BACKUP_ROLE_PASSWORD
```

`secrets/aws_credentials`:

```ini
[default]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
```

### IAM least privilege (document on AWS)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject"],
      "Resource": "arn:aws:s3:::YOUR_BUCKET/postgres-backups/*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::YOUR_BUCKET",
      "Condition": {
        "StringLike": { "s3:prefix": ["postgres-backups/*"] }
      }
    }
  ]
}
```

Enable S3 bucket versioning or object lock outside this repository.

## 5. Safe update procedure

1. Confirm Compose project name: `docker compose ls` (from each service directory).
2. Record current mounts: `docker inspect postgres_db --format '{{json .Mounts}}'`
3. Take a manual database backup before changes:

```bash
cd postgres
docker exec postgres_db pg_dump -U postgres -Fc micasa-prod > /tmp/pre-hardening.dump
ls -lh /tmp/pre-hardening.dump   # must be non-empty
```

4. Create secret files if migrating from the old inline-command backup layout.
5. Validate: `docker compose config -q`
6. Pull/build without stopping data volume:

```bash
docker compose pull database
docker compose build postgres_backup_to_s3
```

7. Recreate one service at a time:

```bash
# Backup first (depends on DB)
docker compose up -d --no-deps postgres_backup_to_s3
docker compose logs -f postgres_backup_to_s3

# Database (preserves postgres_data volume)
docker compose up -d --no-deps database
docker compose ps
docker exec postgres_db pg_isready -U postgres
```

8. Test Vercel connectivity to `micasa-prod` as `vercel`.
9. Trigger backup manually: `docker exec postgres_backup /usr/local/bin/backup.sh`
10. For Cronicle (separate project directory):

```bash
cd ../cronicle
docker compose build
docker compose up -d
ss -tlnp | grep 3012   # must show 127.0.0.1:3012
```

11. Test `https://your-cronicle-host` through Caddy.
12. Confirm port 3012 is not reachable externally.

**Never run** `docker compose down -v`, `docker volume rm`, or `docker system prune --volumes`.

## 6. Backup procedure

- Scheduled via cron inside `postgres_backup` container (`BACKUP_CRON`, default `0 2 * * *`).
- Format: `pg_dump --column-inserts --create`, gzip compressed, uploaded to `s3://BUCKET/postgres-backups/` with `--sse AES256`.
- Retention: local copies removed after successful upload; configure S3 lifecycle/versioning on the bucket.
- Logs: `docker logs postgres_backup` and `/var/log/backup.log` inside the container.

## 7. Restore-test procedure

Perform quarterly on a non-production host:

```bash
# Download a backup from S3
aws s3 cp s3://YOUR_BUCKET/postgres-backups/postgres_backup_YYYY-MM-DD_HH-MM-SS.sql.gz /tmp/

# Restore to a throwaway instance
gunzip -c /tmp/postgres_backup_*.sql.gz | psql -h localhost -U postgres -d postgres

# Verify row counts / application smoke test
```

Document results and backup age. A backup that has never been restored is unverified.

## 8. Incident response basics

1. **Suspected DB compromise:** rotate `vercel` and `backup` passwords, review `pg_stat_activity`, check PostgreSQL logs, snapshot volume before destructive changes.
2. **Suspected Cronicle compromise:** stop container, rotate Cronicle/HMS/SMTP secrets, review job history and spawned processes, restore from known-good image tag.
3. **Leaked AWS keys:** deactivate IAM key, audit S3 access logs, rotate `secrets/aws_credentials`.
4. **Leaked Git secret:** rotate credential immediately; do not rely on deleting the file from HEAD alone.

## 9. Verification commands

```bash
./scripts/validate-security.sh

cd postgres && docker compose config -q
cd cronicle && docker compose config -q

# Port bindings
ss -tlnp | grep -E ':(5432|3012|443) '

# Health
docker inspect postgres_db --format '{{.State.Health.Status}}'
docker inspect cronicle --format '{{.State.Health.Status}}'

# No docker socket
docker inspect postgres_db cronicle postgres_backup --format '{{json .HostConfig.Binds}}' | grep -i sock && echo FAIL || echo OK

# pg_hba active
docker exec postgres_db psql -U postgres -c "SHOW hba_file;"
```

## 10. Rollback instructions

Keep the previous Compose file and image IDs:

```bash
docker inspect postgres_db --format '{{.Config.Image}}'
docker inspect postgres_backup --format '{{.Image}}'
```

Rollback database service (volume unchanged):

```bash
cd postgres
git checkout HEAD~1 -- docker-compose.yml pg_hba.conf   # or known-good commit
docker compose up -d --no-deps database
```

Rollback backup:

```bash
docker compose up -d --no-deps postgres_backup_to_s3
```

Rollback Cronicle:

```bash
cd cronicle
git checkout HEAD~1 -- docker-compose.yml Dockerfile
docker compose build --no-cache
docker compose up -d
```

If `pg_hba.conf` changes lock out Vercel, restore the previous file and reload:

```bash
docker compose up -d --no-deps database
# or temporarily connect via docker exec and edit hba, then SELECT pg_reload_conf();
```

## Host-level Docker forwarding policy

UFW rules do not affect Docker-published ports. To add defense in depth on Debian:

```bash
# Example: insert rules in DOCKER-USER chain (test before applying to production)
iptables -I DOCKER-USER -p tcp --dport 5432 -j ACCEPT
# Add explicit DROP rules for unwanted exposure as needed
```

Document any host `iptables`/`nftables` changes outside this repository.

## Image pinning and updates

| Image | Pinned tag | Update approach |
|-------|------------|-----------------|
| PostgreSQL | `postgres:15.18-alpine3.21` | Review PG release notes; test on staging; `docker compose pull` |
| Backup base | `alpine:3.21.7` | Rebuild backup image after Alpine security patches |
| Cronicle | `cronicle/edge:v1.14.4` | Rebuild custom image; test job execution |
| Minecraft | `itzg/minecraft-server:java21` | Pin deliberately; test world compatibility |

Digest pinning (`image: name@sha256:...`) improves reproducibility but complicates routine patch pulls. Tags are pinned here; record digests in deployment notes if your process requires them.

## Caddy (host)

See `caddy/Caddyfile.example` and `caddy/README.md`. Use HTTPS, basic auth, and reverse proxy to `127.0.0.1:3012` only.
