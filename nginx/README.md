# Nginx Web Server

This setup provides a standalone nginx web server for serving web applications.

## Features

- Nginx with HTTP and HTTPS support
- Configurable virtual hosts
- SSL support
- Static file serving

## Directory Structure

```
nginx/
├── conf.d/         # Virtual host configurations
├── html/           # Web root directory
├── ssl/            # SSL certificates
├── nginx.conf      # Main nginx configuration
└── docker-compose.yml
```

## Setup

1. Create necessary directories:
```bash
mkdir -p conf.d html ssl
```

2. Add your SSL certificates to the `ssl` directory

3. Create virtual host configurations in `conf.d/`

4. Start the service:
```bash
docker-compose up -d
```

## Adding a Virtual Host

1. Create a new configuration file in `conf.d/`:
```nginx
server {
    listen 80;
    server_name example.com;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
```

2. For HTTPS, add SSL configuration:
```nginx
server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
```

## SSL Configuration

Place your SSL certificates in the `ssl` directory:
- Certificate: `ssl/your-domain.crt`
- Private key: `ssl/your-domain.key`

## Security Notes

- Always use HTTPS in production
- Keep nginx and its modules updated
- Implement proper security headers
- Use strong SSL/TLS configurations
- Regularly rotate SSL certificates 