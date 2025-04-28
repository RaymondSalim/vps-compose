FROM nginx:alpine

# Install required packages
RUN apk add --no-cache certbot openssl

# Create directory for SSL certificates
RUN mkdir -p /etc/nginx/ssl

# Copy the certificate management script
COPY certbot.sh /usr/local/bin/certbot.sh
RUN chmod +x /usr/local/bin/certbot.sh

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80 for certbot challenge
EXPOSE 80

# Generate certificates and start nginx
CMD ["sh", "-c", "/usr/local/bin/certbot.sh && nginx -g 'daemon off;'"] 