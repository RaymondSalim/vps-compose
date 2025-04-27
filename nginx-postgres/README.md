# PostgreSQL with Nginx Proxy and S3 Backup

This setup provides a secure PostgreSQL database with Nginx as a reverse proxy and automated daily backups to S3.

## Features

- PostgreSQL 15 database
- Nginx reverse proxy for secure database access
- Automated daily backups to S3
- 14-day backup retention (managed by S3 lifecycle rules)
- Comprehensive logging
- Docker-based deployment

## Prerequisites

- Docker and Docker Compose
- AWS account with S3 bucket
- AWS credentials with S3 access

## Configuration

### Environment File

Copy `.env.example` to `.env` and configure your environment variables:

```bash
# PostgreSQL Configuration
POSTGRES_USER=your_user
POSTGRES_PASSWORD=your_password
POSTGRES_DB=your_database

# AWS Configuration
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_DEFAULT_REGION=your_region
S3_BUCKET_NAME=your_bucket_name
```

### S3 Lifecycle Rules

Set up a lifecycle rule in your S3 bucket for 14-day retention:
```bash
aws s3api put-bucket-lifecycle-configuration \
    --bucket micasa-postgres-backup-test \
    --lifecycle-configuration '{
        "Rules": [
            {
                "ID": "DeleteOldBackups",
                "Status": "Enabled",
                "Prefix": "postgres-backups/",
                "Expiration": {
                    "Days": 14
                }
            }
        ]
    }'
```

## Usage

### Starting the Services

```bash
# Build the backup container
docker-compose build postgres_backup_to_s3

# Start all services
docker-compose up -d
```

### Accessing the Database

- Through Nginx proxy: `your_server:80`
- Direct PostgreSQL access (internal only): `database:5432`

### Monitoring

View backup logs:
```bash
# Backup script logs
docker exec postgres_backup cat /backups/backup.log

# Cron logs
docker exec postgres_backup cat /backups/cron.log

# Follow logs in real-time
docker exec postgres_backup tail -f /backups/backup.log
```

### Backup Schedule

- Backups run every 5 minutes (configurable in docker-compose.yml)
- Backups are stored in S3 under the `postgres-backups/` prefix
- Old backups are automatically deleted after 14 days

## Security Considerations

- Only port 80 is exposed to the outside world
- Database access is proxied through Nginx
- AWS credentials are managed through environment variables
- S3 bucket should have appropriate access controls
- Consider using AWS KMS for encryption at rest

## Troubleshooting

1. **Backup Fails**
   - Check the backup logs: `docker exec postgres_backup cat /backups/backup.log`
   - Verify AWS credentials in .env
   - Ensure S3 bucket exists and is accessible

2. **Database Connection Issues**
   - Verify PostgreSQL is running: `docker ps`
   - Check network connectivity between containers
   - Verify environment variables in .env

3. **Nginx Proxy Issues**
   - Check nginx logs: `docker logs nginx`
   - Verify nginx.conf configuration
   - Ensure port 80 is not blocked by firewall

## License

MIT 