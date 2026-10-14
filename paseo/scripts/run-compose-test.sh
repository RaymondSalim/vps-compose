#!/usr/bin/env bash
# Installed as paseo-test. Usage: paseo-test path/to/compose.test.yml
# The Compose file must define a test service, and its disposable dependencies.
set -Eeuo pipefail
compose_file=${1:?Usage: paseo-test path/to/compose.test.yml}
[[ -f $compose_file ]] || { printf 'No such Compose file: %s\n' "$compose_file" >&2; exit 2; }

# Pin the intended socket, ignoring inherited contexts or TLS configuration.
export DOCKER_HOST=unix:///run/agent-docker/docker.sock
unset DOCKER_CONTEXT DOCKER_TLS DOCKER_TLS_VERIFY DOCKER_CERT_PATH DOCKER_API_VERSION
security=$(docker info --format '{{json .SecurityOptions}}')
[[ $security == *rootless* ]] || { printf 'Expected rootless Docker; refusing to run.\n' >&2; exit 1; }

project="test-$(date +%s)-$(cat /proc/sys/kernel/random/uuid)"
cleanup() {
  status=$?
  trap - EXIT
  if ! docker compose -f "$compose_file" -p "$project" down --volumes --remove-orphans; then
    printf 'Cleanup failed for project %s. Clean up that project explicitly.\n' "$project" >&2
    if (( status == 0 )); then status=1; fi
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'Test project: %s\n' "$project"
docker compose -f "$compose_file" -p "$project" up \
  --build --abort-on-container-exit --exit-code-from test
