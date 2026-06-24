#!/usr/bin/env bash

# Log Cleanup Cron Job
# This script cleans up old log files

set -e

# Configuration
LOG_DIR="/opt/cronicle/logs/hms"
RETENTION_DAYS=30
LOG_FILE="/opt/cronicle/logs/hms/cleanup-logs.log"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting log cleanup job..."

# Check if log directory exists
if [ ! -d "$LOG_DIR" ]; then
    log "Log directory does not exist: $LOG_DIR"
    exit 0
fi

# Find and remove old log files (older than RETENTION_DAYS days)
old_files=$(find "$LOG_DIR" -name "*.log" -type f -mtime +$RETENTION_DAYS 2>/dev/null || true)

if [ -n "$old_files" ]; then
    log "Found old log files to remove:"
    echo "$old_files" | while read -r file; do
        log "Removing: $file"
        rm -f "$file"
    done
    log "Log cleanup completed successfully"
else
    log "No old log files found to remove"
fi

log "Log cleanup job completed"
exit 0 