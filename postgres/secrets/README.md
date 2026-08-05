# Secret files for the backup container. These paths are gitignored.
#
# pgpass format (mode 0600, one line; user must match BACKUP_USER in .env):
#   database:5432:micasa-prod:backup:YOUR_BACKUP_ROLE_PASSWORD
#
# aws_credentials format (mode 0600, ini):
#   [default]
#   aws_access_key_id = YOUR_ACCESS_KEY_ID
#   aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
#
# On the VPS:
#   mkdir -p secrets && chmod 700 secrets
#   install -m 600 /dev/null secrets/pgpass
#   install -m 600 /dev/null secrets/aws_credentials
#   # edit both files with the formats above
#
# IAM policy should allow only:
#   s3:PutObject, s3:GetObject on arn:aws:s3:::YOUR_BUCKET/postgres-backups/*
#   s3:ListBucket with prefix condition on postgres-backups/
