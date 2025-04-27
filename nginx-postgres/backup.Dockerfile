FROM alpine:3.19

# Install required packages
RUN apk add --no-cache \
    postgresql15-client \
    aws-cli \
    cronie \
    tzdata

# Create backup directory
RUN mkdir -p /backups

# Create .pgpass in a location accessible by crond
RUN touch /root/.pgpass && \
    chmod 600 /root/.pgpass && \
    chown root:root /root/.pgpass

# Set working directory
WORKDIR /backups