# PostgreSQL with SSL and S3 Backup

This setup provides a PostgreSQL database with SSL encryption and automated S3 backups.

## Features

- PostgreSQL 15 with SSL/TLS encryption
- Automated backups to S3
- Self-signed SSL certificates (can be replaced with proper certificates)

## Setup

1. Create the `.env` file with your configuration:
```bash
cp .env.example .env
```

2. Generate SSL certificates:
```bash
chmod +x generate-ssl.sh
./generate-ssl.sh
```

3. Start the services:
```bash
docker-compose up -d
```

## SSL Configuration

The setup uses self-signed certificates by default. For production use, replace the certificates in the `ssl` directory with proper SSL certificates from a trusted CA.

## Backup Configuration

Backups are configured to run every minute by default. You can modify the cron schedule in the `docker-compose.yml` file.

## Environment Variables

Required environment variables:
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_DB`
- `POSTGRES_HOST`
- `POSTGRES_PORT`
- `S3_BUCKET_NAME`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION`

## Connecting to PostgreSQL

To connect to PostgreSQL with SSL:

```bash
psql "sslmode=require host=localhost port=5432 dbname=your_db user=your_user"
```

## Security Notes

- The default setup uses self-signed certificates for development
- For production, use proper SSL certificates from a trusted CA
- Ensure proper firewall rules are in place
- Regularly rotate your database credentials
- Monitor backup success/failure 

## TODO!
Fix email system