FROM alpine:latest

# Install required packages
RUN apk add --no-cache postgresql15-client aws-cli cronie tzdata

# Create backup directory
RUN mkdir -p /backups

# Set working directory
WORKDIR /backups