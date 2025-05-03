#!/bin/sh

# Log function that writes to both docker logs and backup.log
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message"  # This goes to docker logs via stdout
    echo "$message" >> /var/log/backup.log  # This goes to backup.log for email
}

# Error function that writes to both docker logs and backup.log
error() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo "$message" >&2  # This goes to docker logs via stderr
    echo "$message" >> /var/log/backup.log  # This goes to backup.log for email
    exit 1
}

# Get current date for backup filename
BACKUP_DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="/backups/postgres_backup_${BACKUP_DATE}.sql.gz"
TEMP_DUMP="/backups/temp_dump.sql"

log "Starting backup process"

# Create backup directory if it doesn't exist
mkdir -p /backups || error "Failed to create backup directory"
log "Backup directory checked/created"

# Dump PostgreSQL database
log "Starting database dump"
if ! pg_dump --column-inserts --create -h "$POSTGRES_HOST" -U "$POSTGRES_USER" "$POSTGRES_DB" > "$TEMP_DUMP"; then
    error "Database dump failed"
fi
log "Database dump completed successfully"

# Compress the dump
log "Compressing dump"
if ! gzip -c "$TEMP_DUMP" > "$BACKUP_FILE"; then
    rm -f "$TEMP_DUMP"
    error "Compression failed"
fi
rm -f "$TEMP_DUMP"
log "Compression completed successfully"

# Upload to S3
log "Starting S3 upload"
if ! aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET_NAME/postgres-backups/"; then
    rm -f "$BACKUP_FILE"
    error "S3 upload failed"
fi
log "S3 upload completed successfully"

# Remove local backup file after upload
rm -f "$BACKUP_FILE" || error "Failed to remove local backup file"
log "Local backup file removed"

log "Backup process completed successfully"
exit 0 