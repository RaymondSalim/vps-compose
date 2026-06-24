#!/usr/bin/env bash

# Email Reminder Cron Job
# This script sends email reminders for unpaid bills

set -e

# Configuration
HMS_API_URL="${HMS_BASE_URL}/api/tasks/email/invoice-reminder"
CRON_SECRET="${HMS_CRON_SECRET}"

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" 
}

log "Starting email reminder job..."

# Make HTTP request to HMS API
response=$(curl -vv -s -w "\n%{http_code}" \
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
    log "Email reminder job completed successfully"
    exit 0
else
    log "Email reminder job failed with HTTP status: $http_code"
    exit 1
fi 