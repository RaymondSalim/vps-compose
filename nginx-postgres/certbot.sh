#!/bin/sh

# Install certbot if not already installed
if ! command -v certbot &> /dev/null; then
    apk add --no-cache certbot
fi

# Create directory for certificates if it doesn't exist
mkdir -p /etc/letsencrypt/live/${DOMAIN}

# Generate certificates if they don't exist
if [ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ] || [ ! -f "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" ]; then
    echo "Generating Let's Encrypt certificates..."
    certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --email ${EMAIL} \
        --domains ${DOMAIN} \
        --preferred-challenges http-01 \
        --http-01-port 80
    
    # Create symlinks for nginx
    ln -sf /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /etc/nginx/ssl/nginx-selfsigned.crt
    ln -sf /etc/letsencrypt/live/${DOMAIN}/privkey.pem /etc/nginx/ssl/nginx-selfsigned.key
    
    # Set proper permissions
    chmod 644 /etc/nginx/ssl/nginx-selfsigned.crt
    chmod 600 /etc/nginx/ssl/nginx-selfsigned.key
    echo "Let's Encrypt certificates generated successfully!"
else
    echo "Let's Encrypt certificates already exist, skipping generation."
fi

# Set up automatic renewal
echo "0 0 * * * certbot renew --quiet --deploy-hook 'nginx -s reload'" >> /etc/crontabs/root
crond -f 