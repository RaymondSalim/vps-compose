#!/usr/bin/env bash
# Exercise lifecycle/error handling without touching a real Docker daemon.
set -Eeuo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
test_tmp=$(mktemp -d)
trap 'rm -rf -- "$test_tmp"' EXIT
mkdir "$test_tmp/bin"
cat > "$test_tmp/bin/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $DOCKER_HOST == unix:///run/agent-docker/docker.sock ]]
[[ ! -v DOCKER_CONTEXT && ! -v DOCKER_TLS && ! -v DOCKER_TLS_VERIFY && ! -v DOCKER_CERT_PATH && ! -v DOCKER_API_VERSION ]]
printf '%s\n' "$*" >> "$MOCK_LOG"
case "$1" in
  info) printf '["name=%s"]\n' "$MOCK_SECURITY" ;;
  compose)
    case " $* " in
      *' up '*) exit "$MOCK_UP_STATUS" ;;
      *' down '*) exit "$MOCK_DOWN_STATUS" ;;
      *) exit 99 ;;
    esac ;;
  *) exit 99 ;;
esac
EOF
chmod +x "$test_tmp/bin/docker"

run_case() {
  local name=$1 security=$2 up=$3 down=$4 expected=$5
  local status=0
  PATH="$test_tmp/bin:$PATH" \
    MOCK_LOG="$test_tmp/$name.log" MOCK_SECURITY="$security" \
    MOCK_UP_STATUS="$up" MOCK_DOWN_STATUS="$down" \
    DOCKER_CONTEXT=production DOCKER_TLS=1 DOCKER_TLS_VERIFY=1 DOCKER_CERT_PATH=/invalid DOCKER_API_VERSION=invalid \
    bash "$script_dir/../scripts/run-compose-test.sh" "$script_dir/compose.smoke.yml" \
    > "$test_tmp/$name.out" 2>&1 || status=$?
  if [[ $status != "$expected" ]]; then
    cat "$test_tmp/$name.out" >&2
    printf '%s: expected status %s, got %s\n' "$name" "$expected" "$status" >&2
    exit 1
  fi
  if [[ $security == rootless ]]; then
    grep -q ' up --build --abort-on-container-exit --exit-code-from test$' "$test_tmp/$name.log"
    grep -q ' down --volumes --remove-orphans$' "$test_tmp/$name.log"
    # Both operations must use the same generated, run-scoped project name.
    local up_project down_project
    up_project=$(awk '/ up / {for(i=1;i<NF;i++) if($i=="-p") print $(i+1)}' "$test_tmp/$name.log")
    down_project=$(awk '/ down / {for(i=1;i<NF;i++) if($i=="-p") print $(i+1)}' "$test_tmp/$name.log")
    [[ $up_project == test-* && $up_project == "$down_project" ]]
  else
    if grep -q '^compose ' "$test_tmp/$name.log"; then
      printf 'Refused daemon still received a Compose command\n' >&2
      exit 1
    fi
  fi
  printf 'PASS %s\n' "$name"
}

run_case success rootless 0 0 0
run_case test-failure rootless 7 0 7
run_case cleanup-failure rootless 0 9 1
run_case both-fail rootless 7 9 7
run_case refuse-rootful seccomp 0 0 1
