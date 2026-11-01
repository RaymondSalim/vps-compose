Paseo runs under the existing host Docker daemon. Agents connect to a separate
rootless Docker daemon owned by the password-locked `agent-tests` host user.
The production Docker socket is never mounted into Paseo.

The repository includes the host setup, client tools, Compose integration and
a PostgreSQL smoke test. Host provisioning and live validation remain deployment
steps. The intended host is Ubuntu 24.04 on ARM64 with Docker CE rootless extras,
cgroup v2/systemd, and an existing block volume at `/mnt/blockvolume`.

| Test resource | Limit shared by the daemon, builds and containers |
| --- | --- |
| CPU | One CPU equivalent (`CPUQuota=100%`) |
| Memory | 1.5 GiB pressure threshold, 2 GiB hard maximum |
| Swap | Zero |
| Tasks/threads | 1,024 |
| Storage | 20 GiB filesystem backed by `/mnt/blockvolume/paseo-test-storage/home.ext4` |

The account's home at `/home/agent-tests` holds its Docker data and build caches
on that bounded filesystem. The backing image is a new regular file, allocated
upfront. Setup never formats the block device or reuses the production Docker
data directory. It requires at least 35 GiB free on the block volume, leaving
15 GiB spare after allocation. The CPU/memory limits belong to the root-owned
parent user slice so container scopes and builds share the same budget.

Run the following on the VPS host from the repository's `paseo/` directory,
before recreating the Paseo container:

```bash
cd /opt/vps-compose/paseo

# Review this first-time provisioning script before running it as root.
less scripts/setup-test-docker.sh
make test-docker-setup

# Recreates Paseo and interrupts active agent sessions; let them finish first.
make up
make test-docker-smoke
```

If the earlier setup bundle has already been installed successfully, skip
`make test-docker-setup`; it uses the same account and paths. The script refuses
to overwrite existing accounts or storage. If a previous attempt stopped partway,
inspect its error and partial state before trying again. It is intentionally
not a destructive reinstall command.

Setup uses the installed Docker CE rootless extras and installs only missing
helper packages. It checks the apt plan for Docker/runtime package changes and
does not request a production Docker upgrade or restart. It adds one fstab entry
and systemd configuration for the new account. A missing block volume prevents
the test daemon from starting. The test filesystem uses `nofail` so its absence
does not make the entire VPS fail to boot. The original fstab is backed up inside
`/mnt/blockvolume/paseo-test-storage`; do not restore that backup over later,
unrelated changes.

Paseo uses `/run/agent-docker/docker.sock`, mapped from
`/var/lib/paseo-test-api/docker.sock`. The persistent directory bind survives
socket recreation. Startup reapplies a socket ACL for Paseo's UID 1000. The
directory mount is read-only, but the Docker API intentionally permits managing
test containers. No D-Bus socket or whole user runtime directory is exposed.
The main Compose file requires the API directory to exist and will fail clearly
if host setup has not been completed. Normal `make up` and `make update` keep this
configuration without a separate override file.

`make test-docker-check` runs as the non-root Paseo user. It checks rootless mode,
the expected Docker data root, and the cgroup driver. `make test-docker-smoke`
then starts PostgreSQL and runs `SELECT 1` from a separate container on the same
Compose network. Expect `smoke_test = 1` and exit status zero. The runner removes
that run's containers, network and volume; the image remains cached. No database
port is published on the VPS. After the next planned VPS reboot, repeat the smoke
test to verify mount/service ordering on the real host.

Inside Paseo, agents can run a project's integration Compose file with:

```bash
paseo-test /workspace/my-project/compose.test.yml
```

The file must contain a `test` service whose command exits with the test result.
Build that service from a project Dockerfile that copies source into the image.
Define database health checks and `depends_on: condition: service_healthy`.
Use service DNS such as `db:5432`. The smoke Compose file in
`tests/compose.smoke.yml` is a complete example of readiness, networking and
disposable data. Replace its SQL runner with the actual project's test image.
Use ARM64-compatible dependency images on this host.

Build contexts are sent from Paseo to the test daemon, so `build.context: .`
works. Bind mounts are resolved on the daemon's host: `.:/app` does not translate
Paseo's `/workspace` into `/opt/vps-compose/paseo/workspace`. The dedicated account
also has not been granted access to that host workspace. Use source-copy builds
with a project `.dockerignore` excluding secrets and caches. Projects that need
bind mounts require explicit path and permission configuration. Do not grant
broad access to production directories to work around that mismatch.

Each invocation receives a unique Compose project name. Avoid fixed
`container_name`, global resource names, external shared volumes and fixed
published ports. Start with one suite at a time given the 2 GiB budget. The
runner preserves test failures and cleans up on normal exit or SIGINT/SIGTERM.
A crash, SIGKILL or unavailable daemon can leave resources; cleanup must target
the printed project name. Never use global prune or remove every container.
Project names prevent accidental collisions; they do not isolate mutually
untrusted agents sharing the same daemon.

Check resource usage from the VPS host:

```bash
test_uid=$(id -u agent-tests)
sudo systemctl show "user-${test_uid}.slice" \
  -p CPUQuotaPerSecUSec -p MemoryCurrent -p MemoryMax -p TasksCurrent -p TasksMax
df -h /home/agent-tests /mnt/blockvolume
sudo journalctl _UID="$test_uid" _SYSTEMD_USER_UNIT=docker.service -n 80 --no-pager
sudo env -u DOCKER_CONTEXT -u DOCKER_HOST docker \
  --host unix:///var/lib/paseo-test-api/docker.sock system df
```

Restart only the test daemon, interrupting all current test runs:

```bash
test_uid=$(id -u agent-tests)
sudo -H -u agent-tests env \
  XDG_RUNTIME_DIR="/run/user/$test_uid" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$test_uid/bus" \
  systemctl --user restart docker
```

Rootless Docker limits access to the dedicated account's permissions, but it
shares the host kernel, physical I/O and network reachability. Paseo itself,
commands run directly inside Paseo, its existing workspace and credentials are
outside the test daemon's resource limits. Other host paths writable by the
dedicated account are also outside the 20 GiB filesystem. A separate VM is the
appropriate boundary for hostile code or strict production isolation.

To roll back repository integration, restore the previous Paseo Compose file
and Dockerfile and recreate Paseo, then stop the test daemon using the command
above with `stop` in place of `restart`. Retain its storage until no longer
needed. Do not delete the backing image while mounted, and do not restore a
whole fstab backup over unrelated updates.

Local validation consists of shell syntax, YAML parsing, Make dry runs and
`bash tests/test-compose-runner.sh`. The latter uses a fake Docker client to
check failure propagation, cleanup and rejection of a rootful daemon; it does
not validate Docker itself. Image build, real container execution and reboot
checks must pass on the VPS before considering deployment complete.

Implementation references:
[Docker rootless mode](https://docs.docker.com/engine/security/rootless/),
[rootless resource limits](https://docs.docker.com/engine/security/rootless/tips/),
[Ubuntu rootless troubleshooting](https://docs.docker.com/engine/security/rootless/troubleshoot/),
[bind-mount semantics](https://docs.docker.com/engine/storage/bind-mounts/), and
[Paseo's runtime user](https://github.com/getpaseo/paseo/blob/main/public-docs/docker.md).
