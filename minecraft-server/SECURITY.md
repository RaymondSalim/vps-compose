# Minecraft server security baseline

This Compose project is separate from PostgreSQL and Cronicle. Apply these controls before exposing a Minecraft server to the Internet.

## Required isolation

- Use a dedicated Compose project and `minecraft_net` network only.
- Do not attach Minecraft containers to `db_internal`, `backup_egress`, or `cronicle_net`.
- Do not mount `/var/run/docker.sock`.
- Do not use `privileged: true` or `network_mode: host`.

## Network exposure

- Publish only the required Minecraft TCP port (`25565`).
- Set `ENABLE_RCON: "false"` or bind RCON to localhost/private networking only.
- Add an explicit UFW rule for `25565/tcp`; do not rely on Docker publishing alone.

## Authentication and access control

- Keep `ONLINE_MODE: "TRUE"` (Mojang authentication).
- Keep `ENABLE_WHITELIST: "true"` and maintain `whitelist.json`.
- Review `ops.json` before deployment.

## Container hardening

- Pin the image tag (no `latest`).
- Use `cap_drop: [ALL]`, `no-new-privileges:true`, `init: true`.
- Set CPU, memory, and PID limits appropriate for the VPS.
- Run as non-root UID/GID when the image supports it (verify `/data` ownership).

## Backups and supply chain

- Back up `./minecraft-data` to storage separate from PostgreSQL backups.
- Review plugins/mods before installation; avoid unreviewed auto-download of executables.
- Pin Minecraft version and image tag; test updates in a non-production environment.

## Resource exhaustion

- Minecraft is memory-heavy; size `mem_limit` and `MEMORY` together to avoid OOM affecting PostgreSQL on the same host.
