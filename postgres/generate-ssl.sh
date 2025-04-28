#!/bin/sh

# Create SSL directory if it doesn't exist
mkdir -p ssl

# Generate SSL certificates if they don't exist
if [ ! -f "ssl/server.key" ] || [ ! -f "ssl/server.crt" ]; then
    echo "Generating SSL certificates for PostgreSQL..."
    
    # Generate private key
    openssl genrsa -out ssl/server.key 2048
    
    # Generate certificate signing request
    openssl req -new -key ssl/server.key -out ssl/server.csr -subj "/CN=localhost"
    
    # Generate self-signed certificate
    openssl x509 -req -days 365 -in ssl/server.csr -signkey ssl/server.key -out ssl/server.crt
    
    # Set proper permissions
    chmod 600 ssl/server.key
    chmod 644 ssl/server.crt
    
    # Clean up CSR
    rm ssl/server.csr
    
    echo "SSL certificates generated successfully!"
else
    echo "SSL certificates already exist, skipping generation."
fi 