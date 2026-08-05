#!/bin/sh
set -eu
umask 077

export PGPASSFILE=/run/secrets/pgpass
export AWS_SHARED_CREDENTIALS_FILE=/run/secrets/aws_credentials

: "${POSTGRES_HOST:?POSTGRES_HOST is required}"
: "${POSTGRES_PORT:?POSTGRES_PORT is required}"
: "${BACKUP_DB:?BACKUP_DB is required}"
: "${BACKUP_USER:?BACKUP_USER is required}"
: "${S3_BUCKET_NAME:?S3_BUCKET_NAME is required}"
: "${AWS_DEFAULT_REGION:?AWS_DEFAULT_REGION is required}"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

error() {
    printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >&2
    exit 1
}

TMPDIR=""
cleanup() {
    if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
        rm -rf "$TMPDIR"
    fi
}
trap cleanup EXIT INT TERM

log "Starting backup process"

mkdir -p /backups || error "Failed to create backup directory"

TMPDIR=$(mktemp -d)
chmod 700 "$TMPDIR"

BACKUP_DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="/backups/postgres_backup_${BACKUP_DATE}.sql.gz"
TEMP_DUMP="${TMPDIR}/dump.sql"

log "Starting database dump"
if ! pg_dump --column-inserts --create \
    -h "$POSTGRES_HOST" \
    -p "$POSTGRES_PORT" \
    -U "$BACKUP_USER" \
    "$BACKUP_DB" > "$TEMP_DUMP"; then
    error "Database dump failed"
fi
log "Database dump completed successfully"

log "Compressing dump"
if ! gzip -c "$TEMP_DUMP" > "$BACKUP_FILE"; then
    error "Compression failed"
fi
chmod 600 "$BACKUP_FILE"
log "Compression completed successfully"

log "Starting S3 upload"
if ! aws s3 cp "$BACKUP_FILE" "s3://${S3_BUCKET_NAME}/postgres-backups/" --sse AES256; then
    log "S3 upload failed; retaining local backup at ${BACKUP_FILE}"
    error "S3 upload failed"
fi
log "S3 upload completed successfully"

rm -f "$BACKUP_FILE" || error "Failed to remove local backup file after successful upload"
log "Local backup file removed after successful upload"

log "Backup process completed successfully"
exit 0
