#!/usr/bin/env bash
# Repository security validation checks. Safe to run locally and in CI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

failures=0

log() { printf '%s\n' "$*"; }
fail() { log "FAIL: $*"; failures=$((failures + 1)); }
pass() { log "PASS: $*"; }

check_compose() {
  local dir="$1"
  log "Validating compose in ${dir}"
  if (cd "$dir" && docker compose config -q); then
    pass "docker compose config (${dir})"
  else
    fail "docker compose config (${dir})"
  fi
}

# Placeholder secrets for postgres compose validation (no real credentials)
if [ ! -f postgres/secrets/pgpass ]; then
  mkdir -p postgres/secrets
  printf 'database:5432:micasa-prod:backup:placeholder\n' > postgres/secrets/pgpass
  printf '[default]\naws_access_key_id = PLACEHOLDER\naws_secret_access_key = PLACEHOLDER\n' > postgres/secrets/aws_credentials
  chmod 600 postgres/secrets/pgpass postgres/secrets/aws_credentials
fi
if [ ! -f postgres/.env ]; then
  cp postgres/.env.example postgres/.env
fi
if [ ! -f cronicle/.env ]; then
  cp cronicle/env.example cronicle/.env
fi
if [ ! -f nginx/.env ]; then
  cp nginx/.env.example nginx/.env
fi

check_compose postgres
check_compose cronicle
check_compose nginx
check_compose minecraft-server

# Cronicle must bind localhost only
if grep -q '127.0.0.1:3012:3012' cronicle/docker-compose.yml; then
  pass "Cronicle binds 127.0.0.1:3012"
else
  fail "Cronicle is not bound to 127.0.0.1:3012"
fi

# PostgreSQL must bind IPv4 explicitly
if grep -q '0.0.0.0:5432:5432' postgres/docker-compose.yml; then
  pass "PostgreSQL binds 0.0.0.0:5432"
else
  fail "PostgreSQL is not explicitly bound to 0.0.0.0:5432"
fi

# No docker.sock mounts in compose/dockerfiles
if grep -RIn 'docker\.sock' --include='docker-compose.yml' --include='Dockerfile' --include='*.Dockerfile' postgres cronicle nginx minecraft-server 2>/dev/null; then
  fail "docker.sock mount detected"
else
  pass "No docker.sock mounts"
fi

# No privileged services
if grep -RIn 'privileged:\s*true' --include='docker-compose.yml' postgres cronicle nginx minecraft-server 2>/dev/null; then
  fail "privileged: true detected"
else
  pass "No privileged services"
fi

# Backup compose command must not embed secrets
if grep -E "POSTGRES_PASSWORD|AWS_SECRET_ACCESS_KEY" postgres/docker-compose.yml; then
  fail "Secrets appear in postgres compose command/environment interpolation"
else
  pass "No secrets in postgres compose command strings"
fi

# Persistent postgres volume path
if grep -q 'postgres_data:/var/lib/postgresql/data' postgres/docker-compose.yml; then
  pass "PostgreSQL data volume path preserved"
else
  fail "PostgreSQL data volume path changed"
fi

# Shell syntax
for script in postgres/backup.sh postgres/backup-entrypoint.sh postgres/generate-ssl.sh nginx/certbot.sh cronicle/jobs/hms/*.sh; do
  if [ -f "$script" ]; then
    if sh -n "$script" 2>/dev/null || bash -n "$script" 2>/dev/null; then
      pass "syntax ${script}"
    else
      fail "syntax ${script}"
    fi
  fi
done

if [ "$failures" -gt 0 ]; then
  log "${failures} check(s) failed"
  exit 1
fi

log "All validation checks passed"
