# Host-side test runner

`paseo-test` is the source for `/usr/local/bin/paseo-test` on the Paseo host. It is root-owned there, so installing a change is an administrator action: `install -m 0755 paseo-test /usr/local/bin/paseo-test`.

## Baseline sizing

The agent-tests user (`user-1002.slice`) is sized for Next.js plus several databases: `MemoryHigh=4G`, `MemoryMax=6G`, `CPUQuota=200%`. A workload that stays between MemoryHigh and MemoryMax is never OOM-killed. The kernel throttles every task in the cgroup instead, including the loop and flush threads behind the ext4 loopback image that holds the rootless Docker data directory, which turns memory pressure into an I/O storm (load average 63 for 35 hours on a 4-core host). Keep MemoryHigh well above what the suites actually use, and rely on per-container limits to fail early.

## What the script enforces

Every service in the Compose file needs `mem_limit` or `deploy.resources.limits.memory`, and the total (times `deploy.replicas`) must fit `PASEO_TEST_MEM_BUDGET_MB` (default 3072, below MemoryHigh to leave room for dockerd and page cache). A violation exits 2 before anything starts. An over-limit container is OOM-killed on its own, so the run fails quickly.

`up` is bounded by `PASEO_TEST_TIMEOUT` seconds (default 900, exit 124 on expiry). On every exit path, including INT and TERM, the EXIT trap runs `down --volumes --remove-orphans --rmi local`, itself bounded to 180 seconds. Compose has no `--rm` for `up`, so `down` is what removes containers, networks and volumes.

## Limits

The trap cannot run if the wrapper is killed with SIGKILL or the host reboots mid-run. Leftover `test-<epoch>-<uuid>` projects then need an explicit `docker compose -p <project> down --volumes`; a host-level reaper for stale projects would close that gap.
