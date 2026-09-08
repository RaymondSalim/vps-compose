#!/usr/bin/env bash

# Late Fees Cron Job
# This script scans overdue bills and applies an automated late fee (Denda
# Keterlambatan) to each qualifying bill (idempotent per bill). Gated
# server-side by the LATE_FEE_AUTOMATION_ENABLED setting.

set -e

# Configuration
HMS_API_URL="${HMS_BASE_URL}/api/cron/late-fees"
CRON_SECRET="${HMS_CRON_SECRET}"

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting late fees job..."

# Make HTTP request to HMS API
response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $CRON_SECRET" \
    -H "Content-Type: application/json" \
    "$HMS_API_URL")

# Extract response body and status code
http_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')

log "HTTP Status Code: $http_code"
log "Response: $response_body"

# Check if the request was successful
if [ "$http_code" -eq 200 ]; then
    log "Late fees job completed successfully"
    exit 0
else
    log "Late fees job failed with HTTP status: $http_code"
    exit 1
fi
