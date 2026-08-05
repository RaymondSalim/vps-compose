# Pin Alpine 3.21 for reproducible backup image builds.
FROM alpine:3.21.7

LABEL org.opencontainers.image.title="postgres-backup-s3" \
      org.opencontainers.image.description="PostgreSQL backup sidecar with S3 upload" \
      org.opencontainers.image.source="https://github.com/RaymondSalim/vps-compose"

RUN apk add --no-cache \
        postgresql15-client \
        aws-cli \
        cronie \
        tzdata \
        logrotate \
    && mkdir -p /backups \
    && touch /var/log/backup.log \
    && chmod 600 /var/log/backup.log

WORKDIR /backups

COPY --chmod=755 backup.sh /usr/local/bin/backup.sh
COPY --chmod=755 backup-entrypoint.sh /usr/local/bin/backup-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/backup-entrypoint.sh"]
