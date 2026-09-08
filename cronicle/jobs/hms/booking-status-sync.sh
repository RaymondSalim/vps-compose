#!/usr/bin/env bash

# Booking Status Sync Cron Job
# This script syncs booking.status_id (and the room it occupies) from each
# booking's start_date/end_date: PENDING -> ACTIVE -> COMPLETED. CANCELLED is
# a terminal state and is never touched. Gated server-side by the
# BOOKING_STATUS_SYNC_ENABLED setting.

set -e

# Configuration
HMS_API_URL="${HMS_BASE_URL}/api/cron/booking-status-sync"
CRON_SECRET="${HMS_CRON_SECRET}"

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting booking status sync job..."

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
    log "Booking status sync job completed successfully"
    exit 0
else
    log "Booking status sync job failed with HTTP status: $http_code"
    exit 1
fi
