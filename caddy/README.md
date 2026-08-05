# Caddy reverse proxy (host-level)

Production uses Caddy on the Debian VPS host, not the nginx Compose project in this repository.

## Cronicle exposure model

- Cronicle binds to `127.0.0.1:3012` only (see `cronicle/docker-compose.yml`).
- Caddy terminates HTTPS on port 443 and reverse-proxies to localhost.
- Port `3012` must not be reachable from the Internet (verify with `ss` or an external port scan).

## Setup

1. Install Caddy on Debian 12 per https://caddyserver.com/docs/install
2. Copy `Caddyfile.example` to `/etc/caddy/Caddyfile` on the VPS
3. Replace `cronicle.example.com` with your real hostname
4. Generate a bcrypt password hash: `caddy hash-password`
5. Reload: `sudo systemctl reload caddy`

## Basic authentication

Caddy basic auth is an additional boundary in front of Cronicle's own login. Use both.

## Verify

```bash
# Cronicle should listen only on localhost
ss -tlnp | grep 3012

# HTTPS should work through Caddy
curl -I https://cronicle.example.com
```

## Docker and UFW note

Published Docker ports bypass UFW by default. Restrict Cronicle at the Compose bind address (`127.0.0.1:3012`), not only with UFW.
