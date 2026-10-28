#!/usr/bin/env bash
# First-time setup only. Run on the VPS host, after reviewing README.md.
set -Eeuo pipefail
umask 077

TEST_USER=agent-tests
TEST_HOME=/home/agent-tests
STORAGE_DIR=/mnt/blockvolume/paseo-test-storage
STORAGE_IMAGE=$STORAGE_DIR/home.ext4
API_DIR=/var/lib/paseo-test-api
STORAGE_GIB=20
PASEO_UID=1000

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
trap 'printf "Setup stopped at line %s. Do not blindly rerun or delete partial state; inspect the error first.\n" "$LINENO" >&2' ERR

[[ $EUID -eq 0 ]] || die 'Run make test-docker-setup on the VPS host.'
. /etc/os-release
[[ $ID == ubuntu && $VERSION_ID == 24.04 ]] || die 'This setup targets Ubuntu 24.04.'
[[ $(uname -m) == aarch64 ]] || die 'This setup targets the supplied ARM64 VPS.'
[[ $(stat -fc %T /sys/fs/cgroup) == cgroup2fs ]] || die 'cgroup v2 is required.'
mountpoint -q /mnt/blockvolume || die '/mnt/blockvolume is not mounted.'
[[ -x /usr/bin/dockerd-rootless-setuptool.sh ]] || die 'Docker CE rootless extras are missing.'
[[ -x /usr/bin/dockerd-rootless.sh ]] || die 'Rootless Docker launcher is missing.'
if getent passwd "$TEST_USER" >/dev/null || getent group "$TEST_USER" >/dev/null; then
  die 'agent-tests already exists; refusing to overwrite an existing account.'
fi
for path in "$TEST_HOME" "$STORAGE_DIR" "$API_DIR"; do
  [[ ! -e $path && ! -L $path ]] || die "Already exists: $path"
done
if grep -Fq '/home/agent-tests' /etc/fstab; then
  die '/etc/fstab already refers to /home/agent-tests.'
fi
free_bytes=$(df -B1 --output=avail /mnt/blockvolume | tail -n 1 | tr -d ' ')
(( free_bytes >= (STORAGE_GIB + 15) * 1024 * 1024 * 1024 )) || die 'Need 35 GiB free on blockvolume (20 GiB allocation plus 15 GiB spare).'

# Explicit host socket: never change the administrator's Docker context.
env -u DOCKER_CONTEXT -u DOCKER_HOST docker --host unix:///var/run/docker.sock info \
  --format 'Existing production Docker data: {{.DockerRootDir}}'

# Install only missing helpers, and abort if dependency resolution would touch
# Docker, containerd or runc. No Docker package upgrade is requested.
needed=()
for pkg in uidmap dbus-user-session slirp4netns acl; do
  if [[ $(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true) != 'install ok installed' ]]; then
    needed+=("$pkg")
  fi
done
if (( ${#needed[@]} )); then
  apt-get update
  install_plan=$(apt-get --simulate --no-upgrade install "${needed[@]}")
  if grep -Eq '^(Inst|Remv) (docker[^ ]*|containerd[^ ]*|runc)( |:)' <<< "$install_plan"; then
    die 'Dependency resolution would modify a container runtime package. Review apt output before proceeding.'
  fi
  NEEDRESTART_MODE=l apt-get install -y --no-upgrade --no-install-recommends "${needed[@]}"
fi

# A normal, password-locked account receives subordinate UID/GID ranges.
useradd --user-group --no-create-home --home-dir "$TEST_HOME" --shell /bin/bash "$TEST_USER"
test_uid=$(id -u "$TEST_USER")
[[ $test_uid != "$PASEO_UID" ]] || die 'The dedicated account must differ from Paseo UID 1000.'
for range_file in /etc/subuid /etc/subgid; do
  awk -F: -v u="$TEST_USER" '$1 == u && $3 >= 65536 { ok=1 } END { exit !ok }' "$range_file" \
    || die "No adequate automatic subordinate range in $range_file; allocate a non-overlapping range before continuing."
done

# Allocate a NEW image file, not a block device or existing Docker directory.
# fallocate reserves space now; no discard option is used for the inner mount.
install -d -m 0700 "$STORAGE_DIR"
(set -o noclobber; : > "$STORAGE_IMAGE")
fallocate -l "${STORAGE_GIB}G" "$STORAGE_IMAGE"
mkfs.ext4 -F -m 0 -E nodiscard "$STORAGE_IMAGE"
install -d -m 0700 "$TEST_HOME"
cp -a /etc/fstab "$STORAGE_DIR/fstab.before-setup"
printf '%s %s ext4 loop,nodev,nosuid,nofail,x-systemd.requires-mounts-for=/mnt/blockvolume 0 0\n' \
  "$STORAGE_IMAGE" "$TEST_HOME" >> /etc/fstab
systemctl daemon-reload
mount "$TEST_HOME"
mountpoint -q "$TEST_HOME"
chown "$TEST_USER:$TEST_USER" "$TEST_HOME"
chmod 0700 "$TEST_HOME"

# Cap the parent user slice, encompassing dockerd, builds and test containers.
# Limits on docker.service alone may miss sibling container scopes.
install -d -m 0755 "/etc/systemd/system/user-${test_uid}.slice.d"
cat > "/etc/systemd/system/user-${test_uid}.slice.d/50-agent-test-limits.conf" <<'EOF'
[Slice]
CPUQuota=100%
CPUWeight=25
MemoryHigh=1536M
MemoryMax=2G
MemorySwapMax=0
TasksMax=1024
EOF

# Configure only this user's manager, not every host user's services.
install -d -m 0755 "/etc/systemd/system/user@${test_uid}.service.d"
cat > "/etc/systemd/system/user@${test_uid}.service.d/50-agent-tests.conf" <<'EOF'
[Unit]
RequiresMountsFor=/mnt/blockvolume /home/agent-tests

[Service]
Delegate=cpu cpuset io memory pids
EOF

install -d -o "$TEST_USER" -g "$TEST_USER" -m 0700 \
  "$TEST_HOME/.config" "$TEST_HOME/.config/docker" \
  "$TEST_HOME/.config/systemd" "$TEST_HOME/.config/systemd/user" \
  "$TEST_HOME/.config/systemd/user/docker.service.d" \
  "$API_DIR" "$TEST_HOME/tmp"

cat > "$TEST_HOME/.config/docker/daemon.json" <<'EOF'
{
  "data-root": "/home/agent-tests/.local/share/docker",
  "log-driver": "local",
  "log-opts": {"max-size": "10m", "max-file": "3"}
}
EOF

# Keep the normal per-user socket so Docker's setup tool can verify startup.
# Paseo sees only the API directory, never the user's runtime or D-Bus sockets.
cat > "$TEST_HOME/.config/systemd/user/docker.service.d/50-paseo-socket.conf" <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd-rootless.sh -H unix://%t/docker.sock -H unix:///var/lib/paseo-test-api/docker.sock
ExecStartPre=/usr/bin/mountpoint -q /home/agent-tests
ExecStartPost=/usr/bin/setfacl -m u:1000:rw /var/lib/paseo-test-api/docker.sock
Environment=TMPDIR=/home/agent-tests/tmp
LimitCORE=0
LogRateLimitIntervalSec=30s
LogRateLimitBurst=200
EOF
chown -R "$TEST_USER:$TEST_USER" "$TEST_HOME/.config"
setfacl -m "u:${PASEO_UID}:rx" "$API_DIR"

systemctl daemon-reload
loginctl enable-linger "$TEST_USER"
systemctl start "user@${test_uid}.service"

as_test_user() {
  sudo -H -u "$TEST_USER" env -u DOCKER_HOST -u DOCKER_CONTEXT \
    XDG_RUNTIME_DIR="/run/user/$test_uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$test_uid/bus" "$@"
}

# Check AppArmor/user-namespace support explicitly before --force, which is
# used solely to permit coexistence with the existing rootful Docker daemon.
as_test_user /usr/bin/rootlesskit true
as_test_user /usr/bin/dockerd-rootless-setuptool.sh install --force

security=$(as_test_user docker --host "unix://$API_DIR/docker.sock" info --format '{{json .SecurityOptions}}')
[[ $security == *rootless* ]] || die 'The new daemon did not report rootless mode.'
as_test_user docker --host "unix://$API_DIR/docker.sock" info \
  --format 'Rootless data={{.DockerRootDir}} Cgroup={{.CgroupVersion}} Driver={{.CgroupDriver}} Security={{json .SecurityOptions}}'
systemctl show "user-${test_uid}.slice" \
  -p CPUQuotaPerSecUSec -p MemoryHigh -p MemoryMax -p MemorySwapMax -p TasksMax
df -h "$TEST_HOME" /mnt/blockvolume
printf '\nHost setup complete. Run make up, then make test-docker-smoke from paseo/.\n'
