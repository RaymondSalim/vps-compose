#!/usr/bin/env bash

# Monthly Billing Cron Job
# This script generates monthly bills for rolling bookings

set -e

# Configuration
HMS_API_URL="${HMS_BASE_URL}/api/cron/monthly-billing"
CRON_SECRET="${HMS_CRON_SECRET}"

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting monthly billing job..."

# Make HTTP request to HMS API
response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $CRON_SECRET" \
    -H "Content-Type: application/json" \
    "$HMS_API_URL")

# Extract response body and status code
http_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | head -n -1)

log "HTTP Status Code: $http_code"
log "Response: $response_body"

# Check if the request was successful
if [ "$http_code" -eq 200 ]; then
    log "Monthly billing job completed successfully"
    exit 0
else
    log "Monthly billing job failed with HTTP status: $http_code"
    exit 1
fi 