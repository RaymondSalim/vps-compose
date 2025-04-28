FROM alpine:latest

# Install required packages
RUN apk add --no-cache postgresql15-client aws-cli cronie tzdata logrotate

# Create backup directory and log file
RUN mkdir -p /backups && \
    touch /var/log/backup.log && \
    chmod 644 /var/log/backup.log

# Create .pgpass in a location accessible by crond
RUN touch /root/.pgpass && \
    chmod 600 /root/.pgpass && \
    chown root:root /root/.pgpass

# Set working directory
WORKDIR /backups

RUN touch /etc/logrotate.d/backup && \
    chmod 644 /etc/logrotate.d/backup
