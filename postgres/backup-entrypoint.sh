#!/bin/sh
set -eu

umask 077

if [ ! -f /run/secrets/pgpass ]; then
    echo "ERROR: missing secret file /run/secrets/pgpass" >&2
    exit 1
fi
if [ ! -f /run/secrets/aws_credentials ]; then
    echo "ERROR: missing secret file /run/secrets/aws_credentials" >&2
    exit 1
fi

chmod 600 /run/secrets/pgpass /run/secrets/aws_credentials 2>/dev/null || true
chmod +x /usr/local/bin/backup.sh

# Crontab contains only the schedule and script path; no credentials.
{
    if [ -n "${CRON_MAILTO:-}" ]; then
        printf 'MAILTO="%s"\n' "$CRON_MAILTO"
    fi
    printf '%s /usr/local/bin/backup.sh >> /proc/1/fd/1 2>&1\n' "${BACKUP_CRON:-0 2 * * *}"
    printf '0 0 * * * /usr/sbin/logrotate /etc/logrotate.d/backup\n'
} > /etc/crontabs/root

chmod 600 /etc/crontabs/root

exec /usr/sbin/crond -f -l 8
