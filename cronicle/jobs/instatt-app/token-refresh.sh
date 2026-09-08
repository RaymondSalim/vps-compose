#!/usr/bin/env bash

# Instatt token refresh (keep Firebase tokens warm)
# Calls the CRON_SECRET-guarded refresh endpoint. Cronicle job config: every
# 30 minutes, no-overlap enabled (see docs/runbooks/token-refresh-cron.md).
# The endpoint answers 200 with a JSON summary on any completed run; non-200
# means auth failure or the refresh worker threw.

set -e

# Configuration
INSTATT_API_URL="${INSTATT_BASE_URL}/api/cron/refresh-tokens"
CRON_SECRET="${INSTATT_CRON_SECRET}"

if [ -z "$INSTATT_BASE_URL" ] || [ -z "$CRON_SECRET" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: INSTATT_BASE_URL and INSTATT_CRON_SECRET must be set in the Cronicle job environment."
    exit 1
fi

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting token refresh..."

# Make HTTP request to the Instatt API
if ! response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $CRON_SECRET" \
    -H "Content-Type: application/json" \
    "$INSTATT_API_URL"); then
    log "curl request failed (connection error)"
    exit 1
fi

# Extract response body and status code
http_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')

log "HTTP Status Code: $http_code"
log "Response: $response_body"

# Check if the request was successful
if [ "$http_code" -eq 200 ]; then
    log "Token refresh completed successfully"
    exit 0
else
    log "Token refresh failed with HTTP status: $http_code"
    exit 1
fi
