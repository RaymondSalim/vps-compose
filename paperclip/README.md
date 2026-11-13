# Paperclip

Self-hosted Paperclip control plane for AI agent teams, running behind Caddy
with the agent CLIs inside the container.

## What runs

- Paperclip server and UI on port 3100, reachable only through Caddy.
- PostgreSQL 17 in a dedicated container, reachable only on the internal
  network.
- Claude Code, Codex, OpenCode, Gemini CLI, and Kimi Code installed in the
  Paperclip image.
- AWS CLI v2 and the `paperclipai` CLI for Bedrock SSO and first-admin
  bootstrap.

## Prerequisites

- Docker Engine with the Compose plugin.
- The `proxy` Docker network used by `caddy/`.
- A DNS A record for the Paperclip hostname pointing at the VPS.
- An AWS SSO profile that can assume the Bedrock role.
- Optional provider keys for Codex and OpenCode.

## First-time setup

1. Create the DNS A record for the Paperclip hostname.
2. Initialize the environment:

   ```sh
   cd /opt/vps-compose/paperclip
   make init
   ```

3. Edit `.env`:
   - Replace `paperclip.example.com` with the real hostname in
     `PAPERCLIP_PUBLIC_URL`, `PAPERCLIP_AUTH_PUBLIC_BASE_URL`, and
     `PAPERCLIP_ALLOWED_HOSTNAMES`.
   - Set `OPENAI_API_KEY` and/or `OPENROUTER_API_KEY` if those agents will be
     used.
4. Create the Bedrock SSO profile:

   ```sh
   make aws-config
   $EDITOR data/.aws/config
   ```

   Fill in `sso_start_url`, `sso_region`, `sso_account_id`, and
   `sso_role_name`.
5. Start the Paperclip stack:

   ```sh
   make up
   ```

6. Replace `paperclip.example.com` in `caddy/Caddyfile` with the real
   hostname, then start or reload Caddy:

   ```sh
   cd ../caddy
   make up
   make reload
   cd ../paperclip
   ```

7. Log in to Bedrock:

   ```sh
   make aws-login
   ```

8. Create the first admin:

   ```sh
   make bootstrap
   ```

   Open the printed invite URL and create the CEO account.
9. Open the Paperclip URL and create the company and agents.

## Bedrock

Claude Code runs against AWS Bedrock. The container exports
`CLAUDE_CODE_USE_BEDROCK=1`, `AWS_PROFILE=bedrock`, and `AWS_REGION=us-west-2`.
The model defaults match the Paseo configuration. When the SSO token expires,
rerun `make aws-login`.

Create a `claude_local` agent in Paperclip with a Bedrock model ID such as
`us.anthropic.claude-opus-5-5`.

## Other agents

The upstream image includes Codex, OpenCode, Gemini CLI, and Kimi Code. Codex
and OpenCode can use the API keys in `.env` or an interactive login:

```sh
make login-codex
make login-opencode
make login-gh
```

For `opencode_local`, set a model in `provider/model` form, for example
`anthropic/claude-sonnet-4-5` or `openai/gpt-5.2-codex`, matching a provider
configured in the container.

## Paperclip Runner

New Claude, Codex, and OpenCode agents default to the experimental Paperclip
Runner. If an environment test fails during Runner setup, open the agent's
Advanced settings and select Legacy runner, then retest. The CLIs remain inside
the container in both modes.

## Portainer

Portainer is a management UI over Docker. It does not replace Compose. This
stack is defined in `paperclip/docker-compose.yml` and is deployed with the
Makefile or `docker compose`.

A Portainer Git-based stack can point at this repository and
`paperclip/docker-compose.yml`. Verify that `env_file: .env` and `./data`
resolve relative to `paperclip/`. Do not use a Portainer web-editor stack for
this layout, because its relative paths resolve under Portainer's own stack
directory. Portainer does not supply the agent CLIs or Bedrock credentials.

## Operations

| Command | Purpose |
| --- | --- |
| `make init` | Create `.env` and generate the required secrets on first run |
| `make aws-config` | Create the SSO profile template in `data/.aws/config` |
| `make up` | Create the `proxy` network if needed and start the stack |
| `make build` | Build the image with a base image pull |
| `make update` | Rebuild with `--pull` and recreate the stack |
| `make down` | Stop the stack, preserving data |
| `make restart` | Restart the stack |
| `make logs` | Follow logs |
| `make ps` | Show status |
| `make shell` | Open a shell as the container's `node` user |
| `make aws-login` | Renew the Bedrock SSO session |
| `make login-codex` | Open the Codex login flow |
| `make login-opencode` | Open the OpenCode login flow |
| `make login-gh` | Open the GitHub CLI login flow |
| `make bootstrap` | Generate the first-admin invite URL |
| `make doctor` | Run Paperclip configuration checks |
| `make agent-versions` | Print installed agent and tool versions |
| `make backup-db` | Write a database dump to `backups/` |

## Backup and restore

Back up both the database and the data directory:

```sh
make backup-db
sudo tar -C . -czf backups/paperclip-data-$(date +%Y%m%d).tgz data
```

`data/` contains uploads, agent workspaces, CLI login state, the SSO cache,
and `instances/default/secrets/master.key`. The master key encrypts provider
credentials stored through the Paperclip UI. Losing it makes those credentials
unrecoverable.

To restore, stop the stack, restore `data/`, restore the SQL dump into the
database, and start the stack. Keep the same `BETTER_AUTH_SECRET` values from
the original `.env`.

Changing `POSTGRES_PASSWORD` after the database volume is initialized does not
update the existing database role. Rotate it inside PostgreSQL first, then
update `.env`.

## Updating

Back up first, then run:

```sh
make update
```

The image follows `ghcr.io/paperclipai/paperclip:latest`, so an update can
include database migrations. Read the upstream update notes and run
`make doctor` after the update.

## Rollback

1. Stop Paperclip with `make down`.
2. Remove the Paperclip block from `caddy/Caddyfile`, then run `make reload`
   in `../caddy`.
3. Keep `data/` and the `paperclip-pgdata` volume until the data is no longer
   needed.

Removing the stack does not delete the database volume or the bind mounted data
directory.

## Troubleshooting

Check the stack and logs:

```sh
make ps
make logs
```

Check the health endpoints:

```sh
docker compose exec paperclip wget -qO- http://127.0.0.1:3100/api/health
docker compose exec paperclip wget -qO- http://127.0.0.1:3100/api/liveness
```

If the UI returns a host mismatch, confirm that the hostname in the browser,
`caddy/Caddyfile`, `PAPERCLIP_PUBLIC_URL`, `PAPERCLIP_AUTH_PUBLIC_BASE_URL`,
and `PAPERCLIP_ALLOWED_HOSTNAMES` match.

If a Claude agent fails, renew the SSO session with `make aws-login` and rerun
the agent environment test.

If an agent fails during Paperclip Runner setup, switch that agent to Legacy
runner.

## Security

- No Docker socket is mounted. Agents cannot control Docker.
- No Paperclip or Postgres ports are published. Caddy is the only ingress.
- The Postgres container is reachable only on the internal network.
- `.env` and `data/` contain credentials. Restrict their permissions.
- The bootstrap invite is one-time. Use it immediately after first start.
- Paperclip runs unattended agents with permission bypass enabled by default.
  Treat the container and any repository it can clone as trusted execution
  scope.
- Restrict access to Portainer, since it can control every stack on the host.

## Resource use

Paperclip and its agents can consume significant CPU and memory. The stack
does not set a hard memory limit initially. Monitor the VPS and add Compose
limits if Paperclip contends with Paseo or other services.
