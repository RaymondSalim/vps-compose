#!/bin/sh

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Get current date for backup filename
BACKUP_DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="/backups/postgres_backup_${BACKUP_DATE}.sql.gz"
TEMP_DUMP="/backups/temp_dump.sql"

log "Starting backup process"

# Create backup directory if it doesn't exist
mkdir -p /backups
log "Backup directory checked/created"

# Dump PostgreSQL database
log "Starting database dump"
if ! pg_dump -h "$POSTGRES_HOST" -U "$POSTGRES_USER" "$POSTGRES_DB" > "$TEMP_DUMP"; then
    log "ERROR: Database dump failed"
    rm -f "$TEMP_DUMP"
    exit 1
fi
log "Database dump completed successfully"

# Compress the dump
log "Compressing dump"
if ! gzip -c "$TEMP_DUMP" > "$BACKUP_FILE"; then
    log "ERROR: Compression failed"
    rm -f "$TEMP_DUMP" "$BACKUP_FILE"
    exit 1
fi
rm -f "$TEMP_DUMP"
log "Compression completed successfully"

# Upload to S3
log "Starting S3 upload"
if ! aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET_NAME/postgres-backups/"; then
    log "ERROR: S3 upload failed"
    rm -f "$BACKUP_FILE"
    exit 1
fi
log "S3 upload completed successfully"

# Remove local backup file after upload
rm -f "$BACKUP_FILE"
log "Local backup file removed"

log "Backup process completed successfully" 