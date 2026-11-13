# Paperclip Integration Design

Date: 2026-11-13
Status: approved for implementation
Scope: add a self-hosted Paperclip stack to the `vps-compose` repository

## Context

This repository is a collection of independent Docker Compose stacks for a
single VPS. Each stack owns its compose file, environment file, and Makefile.
Caddy is the public ingress and runs on an external `proxy` network. Paseo is
the existing agent workspace product, and its container includes the agent
CLIs so agents run inside the container rather than on the host.

Paperclip is a self-hosted control plane for AI agent teams. Its published
Docker image already includes the local agent CLIs used by its adapters:
Claude Code, Codex, OpenCode, Gemini CLI, and Kimi Code. This integration adds
Paperclip as another stack, keeps the agent CLIs inside the Paperclip
container, and uses the same Bedrock authentication model as Paseo.

The host is aarch64 with 4 vCPU and 23 GiB RAM. The official Paperclip image
is published for both amd64 and arm64.

## Goals

- Add a reproducible `paperclip/` stack with a compose file, Makefile, and
  README consistent with the other stacks in this repository.
- Run Paperclip behind Caddy over HTTPS in authenticated public mode.
- Run Claude Code, Codex, OpenCode, Gemini CLI, and Kimi Code inside the
  Paperclip container.
- Authenticate Claude Code against AWS Bedrock with the same SSO profile and
  model IDs as Paseo.
- Persist Paperclip data, the database, and CLI authentication state across
  restarts.
- Provide Make targets for first-time setup, bootstrap, updates, and backups.

## Non-goals

- Mounting the production Docker socket. Agents do not get Docker access in
  this integration.
- Bundling Chromium or `agent-browser`. The upstream image does not include
  them, and browser automation is a separate concern.
- Reusing the existing `postgres/` stack. Paperclip gets its own database.
- Supporting Portainer's web-editor stack layout. Compose on disk remains the
  source of truth.
- Configuring off-site backups. A local database dump target is included.

## Architecture

```text
Internet
   |
   v
Caddy (external proxy network)
   |
   v
paperclip:3100
   |            \
   |             \-- ./data mounted at /paperclip (bind mount)
   v
db:5432 (internal network only)
```

Caddy terminates TLS and forwards requests to the Paperclip service over the
external `proxy` network. The database is reachable only from the Paperclip
service over an internal bridge network. Paperclip publishes no host ports.
The host reaches the UI only through Caddy.

## Components and Files

| Path | Purpose |
| --- | --- |
| `paperclip/Dockerfile` | Thin derivative of the official Paperclip image adding AWS CLI v2 and the `paperclipai` CLI |
| `paperclip/.dockerignore` | Keeps runtime data, backups, and secrets out of the build context |
| `paperclip/docker-compose.yml` | Paperclip service, Postgres service, networks, and volumes |
| `paperclip/Makefile` | Setup, lifecycle, authentication, bootstrap, and backup targets |
| `paperclip/.env.example` | Documented environment template |
| `paperclip/aws-config.example` | Bedrock SSO profile template matching Paseo |
| `paperclip/README.md` | Deployment, operation, Portainer, and recovery instructions |
| `caddy/Caddyfile` | New `paperclip.example.com` reverse proxy block |
| `.gitignore` | Ignore `paperclip/data/` and `paperclip/backups/` |

## Image Design

The image is built from `ghcr.io/paperclipai/paperclip:latest`. The upstream
image is multi-arch and is the authoritative source for the agent CLIs,
`gh`, `git`, `ripgrep`, `jq`, `python3`, and the application itself.

The derivative adds two things:

1. AWS CLI v2, installed for the build architecture. Needed for Bedrock SSO
   device-code login inside the container.
2. The `paperclipai` CLI from npm, installed globally. Needed for
   `auth bootstrap-ceo` and `doctor`, because public authenticated instances
   do not allow the browser first-admin claim.

The upstream `ENTRYPOINT`, `CMD`, environment, and root-then-gosu startup are
preserved. The container starts as root only so the upstream entrypoint can
repair ownership of the data volume, then the application and agents run as
the `node` user.

The build context is `paperclip/`. `data/`, `backups/`, and `.env` are
excluded. The resulting image is tagged `paperclip-with-agents`.

## Compose Design

### paperclip service

- Build from `paperclip/Dockerfile` and tag `paperclip-with-agents`.
- Container name `paperclip`.
- `restart: unless-stopped`.
- `pids_limit: 2048` and `stop_grace_period: 90s`, matching upstream guidance.
- `env_file: .env`.
- Environment overrides:
  - `DATABASE_URL=postgres://paperclip:${POSTGRES_PASSWORD}@db:5432/paperclip`
  - `HOST=0.0.0.0`
  - `PORT=3100`
  - `PAPERCLIP_HOME=/paperclip`
  - `SERVE_UI=true`
- Bind mount `./data:/paperclip`.
- Networks `internal` and `proxy`.
- Depends on `db` with `condition: service_healthy`.
- No published ports.
- No Docker socket.
- No `init: true`. The upstream entrypoint makes tini PID 1.

### db service

- Image `postgres:17-alpine`.
- Environment from `.env`: `POSTGRES_USER=paperclip`,
  `POSTGRES_PASSWORD`, `POSTGRES_DB=paperclip`.
- Named volume `paperclip-pgdata:/var/lib/postgresql/data`.
- Healthcheck `pg_isready -U paperclip -d paperclip`.
- Network `internal` only.
- No published ports.
- `restart: unless-stopped`.

### Networks and volumes

- `internal`: bridge network for Paperclip to database traffic.
- `proxy`: external network shared with Caddy.
- `paperclip-pgdata`: named volume outside the Paperclip data directory so
  the application's ownership repair never touches Postgres files.

## Configuration and Secrets

`paperclip/.env.example` documents the full environment. The real `.env` is
ignored by the repository's existing `.env` rule.

Required secrets, each generated as a separate 32-byte hex value:

- `BETTER_AUTH_SECRET`: signs sessions.
- `PAPERCLIP_AGENT_JWT_SECRET`: signs agent API tokens.
- `PAPERCLIP_TOOL_ACTION_SIGNING_SECRET`: signs approval-gated tool actions.
- `POSTGRES_PASSWORD`: database password.

Deployment and URL settings:

- `PAPERCLIP_DEPLOYMENT_MODE=authenticated`
- `PAPERCLIP_DEPLOYMENT_EXPOSURE=public`
- `PAPERCLIP_PUBLIC_URL=https://paperclip.example.com`
- `PAPERCLIP_AUTH_PUBLIC_BASE_URL=https://paperclip.example.com`
- `PAPERCLIP_ALLOWED_HOSTNAMES=paperclip.example.com`
- `PAPERCLIP_MIGRATION_AUTO_APPLY=true`
- `TRUST_PROXY=1`

Bedrock settings for Claude Code, matching Paseo:

- `CLAUDE_CODE_USE_BEDROCK=1`
- `AWS_PROFILE=bedrock`
- `AWS_REGION=us-west-2`
- `ANTHROPIC_MODEL=us.anthropic.claude-opus-5-5`
- `ANTHROPIC_SMALL_FAST_MODEL=us.anthropic.claude-sonnet-5-5`
- `ANTHROPIC_DEFAULT_SONNET_MODEL=us.anthropic.claude-sonnet-5-5`
- `ANTHROPIC_DEFAULT_OPUS_MODEL=us.anthropic.claude-opus-5-5`
- `ANTHROPIC_DEFAULT_HAIKU_MODEL=us.anthropic.claude-haiku-5-5`
- `CLAUDE_CODE_MAX_OUTPUT_TOKENS=32768`
- `MAX_THINKING_TOKENS=8192`

Provider keys for the other agents are placeholders in `.env.example`:

- `OPENAI_API_KEY` for Codex.
- `OPENROUTER_API_KEY` for OpenCode.

`make init` copies `.env.example` to `.env` if no `.env` exists and generates
the four secrets on that first creation only. Re-running `make init` never
rotates existing secrets.

The Paperclip secrets master key is generated by the application under
`data/instances/default/secrets/master.key`. It encrypts provider credentials
stored through the Paperclip UI. Backing up `data/` is mandatory. Losing the
master key makes stored secrets unrecoverable.

## Authentication Design

### Claude Code and Bedrock

`paperclip/aws-config.example` mirrors `paseo/paseo-home/.aws/config` with
placeholder SSO values. `make aws-config` creates `data/.aws/config` from the
template if it does not exist. The operator fills in the SSO start URL, region,
account ID, and role name.

`make aws-login` runs the SSO device-code flow as the `node` user inside the
container. The SSO cache lives under `data/.aws/sso/cache` and survives
container recreation. When the token expires, the operator reruns
`make aws-login`.

Claude agents are created in the Paperclip UI with the `claude_local`
adapter and a Bedrock profile model ID such as
`us.anthropic.claude-opus-5-5`. The server environment already carries the
Bedrock switch, profile, region, and model defaults.

### Codex, OpenCode, Gemini, and Kimi

These CLIs are installed by the upstream image. Codex and OpenCode can use
API keys from `.env` or interactive login state persisted in `./data`.
`make login-codex`, `make login-opencode`, and `make login-gh` run the
interactive flows as the `node` user.

Paperclip adapters are configured in the UI. For `opencode_local`, the model
must be in `provider/model` form, for example `anthropic/claude-sonnet-4-5` or
`openai/gpt-5.2-codex`, matching a provider configured in the container. For
`codex_local`, the model can be left unset to use the Codex default or set to a
model available to the configured account.

### Paperclip Runner caveat

On this platform, new Claude, Codex, and OpenCode agents default to the
experimental Paperclip Runner. If an environment test fails with a Runner
setup error, set the agent's Advanced runner option to Legacy runner and
retest. The agent CLIs remain inside the container in both modes.

## Bootstrap

Public authenticated instances do not expose the browser first-admin claim;
that route exists only in private exposure. After the stack is healthy,
`make bootstrap` runs:

```text
paperclipai auth bootstrap-ceo
```

The command prints a one-time invite URL. The operator opens it, creates the
CEO account, and then configures the company and agents. `make doctor` runs
Paperclip's configuration and environment checks.

## Caddy

Add a site block to `caddy/Caddyfile`:

```text
paperclip.example.com {
	reverse_proxy paperclip:3100 {
		flush_interval -1
	}
}
```

Caddy obtains the TLS certificate automatically. `TRUST_PROXY=1` tells
Paperclip to trust one proxy hop so client IPs and rate limiting see the real
caller. The hostname in the Caddy block, `PAPERCLIP_PUBLIC_URL`,
`PAPERCLIP_AUTH_PUBLIC_BASE_URL`, and `PAPERCLIP_ALLOWED_HOSTNAMES` must all
match.

## Operations

| Target | Behavior |
| --- | --- |
| `make init` | Create `.env` from the template and generate secrets once |
| `make aws-config` | Create `data/.aws/config` from the template if missing |
| `make up` | Ensure the `proxy` network exists and start the stack |
| `make build` | Build the derivative image with a base image pull |
| `make update` | Rebuild with `--pull` and recreate the stack |
| `make down` | Stop the stack, preserving volumes and data |
| `make restart` | Restart the stack |
| `make logs` | Follow logs |
| `make ps` | Show stack status |
| `make shell` | Open a shell as `node` in the Paperclip container |
| `make aws-login` | Run Bedrock SSO device-code login |
| `make login-codex` | Run interactive Codex login |
| `make login-opencode` | Run interactive OpenCode login |
| `make login-gh` | Run interactive GitHub CLI login |
| `make bootstrap` | Generate the first-admin invite URL |
| `make doctor` | Run `paperclipai doctor` |
| `make agent-versions` | Print installed agent and tool versions |
| `make backup-db` | Write a `pg_dump` to `backups/` |

Start order:

1. Create the DNS `A` record for the Paperclip hostname.
2. `cd paperclip && make init`.
3. Edit `.env` and replace the placeholder hostname and provider keys.
4. `make aws-config` and fill in the SSO profile values.
5. `make up`.
6. `make aws-login`.
7. `make bootstrap` and open the invite URL.
8. Create the company and agents in the UI.

Database backup and restore:

- `make backup-db` writes a timestamped SQL dump under `paperclip/backups/`.
- Back up `paperclip/data/` separately, for example with `tar`. It contains
  the Paperclip database metadata, uploads, agent workspaces, CLI auth state,
  the SSO cache, and the secrets master key.
- To restore, stop Paperclip, restore `data/`, restore the SQL dump into the
  database, and start the stack.

## Portainer

Portainer is a management UI and API over Docker. It does not replace Compose
as the deployable definition. This integration keeps `paperclip/docker-compose.yml`
as the source of truth and uses the repository's existing CLI Compose
workflow.

A Portainer Git-based stack can point at the repository and the compose file
path. Verify that `env_file: .env` and the `./data` bind mount resolve relative
to `paperclip/`. The CLI Compose path remains the tested deployment path.

A Portainer web-editor stack is not supported for this layout. Its relative
paths resolve under Portainer's own stack directory, so the env file and data
directory would not match the repository. Portainer also cannot provide the
agent CLIs or the Bedrock credentials; those come from the image and the
container data volume.

## Security

- No production Docker socket is mounted. Agents cannot control Docker or
  reach other containers through the daemon.
- Paperclip publishes no host ports. Only Caddy is exposed.
- The database publishes no ports and is reachable only on the internal
  network.
- The container starts as root only to repair volume ownership, then runs the
  application and agents as `node`.
- `.env` and `data/` contain credentials. They are host-local, ignored by Git,
  and should be readable only by the deployment user.
- The bootstrap invite URL is one-time and should be used immediately after
  first start. Do not leave a fresh public instance unclaimed.
- Paperclip runs unattended agents with permission bypass enabled by default.
  Treat the container and every repository it can clone as trusted execution
  scope. Do not give it credentials broader than the work requires.
- Restrict access to Portainer itself, since it can control every stack on the
  host.

## Risks and Open Questions

- The image tracks `latest`. An update can include database migrations. Back up
  before `make update` and read the upstream update notes.
- The Paperclip Runner is experimental. Legacy runner is the fallback.
- Bedrock SSO tokens expire and require interactive renewal.
- Paperclip and Paseo agents can both consume significant CPU and memory. No
  hard memory limit is set initially. Monitor the host and add limits if
  contention appears.
- The `paperclipai` CLI version is installed at image build time and can drift
  from a newer server image. Rebuild the derivative image during updates so
  both move together.
- The repository's `feat/paseo-uiux-skills` branch has an uncommitted
  `caddy/Caddyfile` OwnTracks block. This branch adds a separate Paperclip
  block from `origin/main`; expect a small merge conflict when combining the
  two.
- The hostname in this design is a placeholder. The deployment requires a real
  DNS record.
- A live UI test cannot be completed from this workspace because it needs
  public DNS and Bedrock SSO credentials. Final verification happens on the
  VPS.

## Test Plan

Local checks:

- `docker compose config` in `paperclip/` and `caddy/`.
- Build the derivative image on the ARM64 test daemon.
- Run `agent-versions` in a one-off container to verify `claude`, `codex`,
  `opencode`, `gemini`, `kimi`, `gh`, and `aws` are present.
- Validate the Caddyfile with the Caddy container's `validate` command.
- Verify `make init` is idempotent and does not rotate existing secrets.

VPS checks after deployment:

- `docker compose ps` shows `paperclip` and `db`, with no host ports on either.
- `docker compose exec paperclip wget -qO- http://127.0.0.1:3100/api/health`
  returns a healthy response.
- The Caddy URL serves the login page over valid HTTPS.
- `make bootstrap` produces a working one-time invite.
- `paperclipai doctor` passes.
- A Claude agent environment test passes against Bedrock after `make aws-login`.
- A Codex or OpenCode environment test passes with its configured key or
  login.
- Restarting the stack preserves the company, agents, and login state.
- The database is not reachable from outside the Docker host.

## Deployment and Rollback

Deployment is the start order above, preceded by adding the DNS record and
updating the Caddy stack. On the VPS:

```text
cd /opt/vps-compose/paperclip
make init
# edit .env
make aws-config
# edit data/.aws/config
make up
make aws-login
make bootstrap
```

Then update and reload Caddy:

```text
cd /opt/vps-compose/caddy
make up
make reload
```

Rollback:

1. `cd paperclip && make down`.
2. Remove the `paperclip.example.com` block from `caddy/Caddyfile`.
3. `cd caddy && make reload`.
4. Keep `paperclip/data/` and the `paperclip-pgdata` volume until the data is
   no longer needed.

Removing the stack does not remove the named database volume or the bind
mounted data directory. That is intentional.
