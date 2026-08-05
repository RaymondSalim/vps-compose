# PostgreSQL with S3 backup

Hardened PostgreSQL 15 deployment for a single VPS with automated S3 backups.

## Features

- PostgreSQL 15.18 on Alpine 3.21 (pinned image tag)
- Host-based authentication via mounted `pg_hba.conf`
- Automated encrypted backups to S3
- Internal Docker network for database traffic; backup egress network for S3

## Important security notes

- **PostgreSQL traffic is not encrypted in transit.** Credentials are protected by SCRAM-SHA-256, but query/response data crosses the Internet in plaintext between Vercel and the VPS. TLS was intentionally not enabled in this repository; mitigate with network monitoring and credential rotation.
- **UFW alone does not block Docker-published ports.** Restrict exposure in Compose (`0.0.0.0:5432:5432` is intentional for Vercel) and use `pg_hba.conf` for role/database limits.
- **Public access is limited by `pg_hba.conf` to the `vercel` role on database `micasa-prod`.** Verify roles exist before rollout.

## Setup

1. Copy environment template:

```bash
cp .env.example .env
```

2. Create secret files (see `secrets/README.md`):

```bash
mkdir -p secrets && chmod 700 secrets
# create secrets/pgpass and secrets/aws_credentials (mode 0600)
```

3. Start services:

```bash
docker compose up -d
```

## Manual VPS steps (first deploy or pg_hba change)

Create the application and backup roles if they do not exist:

```sql
-- Connect via docker exec as superuser
CREATE ROLE vercel LOGIN PASSWORD '...';
GRANT CONNECT ON DATABASE "micasa-prod" TO vercel;
-- grant least-privilege on schema/tables as required by the app

CREATE ROLE backup LOGIN PASSWORD '...';
GRANT CONNECT ON DATABASE "micasa-prod" TO backup;
-- grant pg_dump privileges (e.g. SELECT on tables or pg_read_all_data in PG15+)
```

Update `secrets/pgpass` with the backup role line:

```
database:5432:micasa-prod:backup:BACKUP_ROLE_PASSWORD
```

## Connecting

From the VPS (local admin):

```bash
docker exec -it postgres_db psql -U postgres
```

From Vercel (application): use the `vercel` role against `micasa-prod` on port 5432 (plaintext transport).

## Backup configuration

- Default schedule: `0 2 * * *` (daily 02:00 UTC)
- S3 path: `s3://$S3_BUCKET_NAME/postgres-backups/`
- Server-side encryption: AES256 on upload
- Local copy is retained if S3 upload fails

See `../SECURITY-HARDENING.md` for restore testing and incident response.
