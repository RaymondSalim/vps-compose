#!/bin/sh
# Installs the global UI/UX skill set for Claude Code, Codex, and OpenCode.
# Runs inside the paseo container as the paseo user (see `make skills`).
#
# The skills CLI writes the real files to ~/.agents/skills/<name> (read by
# Codex and OpenCode) and symlinks ~/.claude/skills/<name> to them (read by
# Claude Code). It records sources and folder hashes in
# ~/.local/state/skills/.skill-lock.json. Re-running is idempotent.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)

export DISABLE_TELEMETRY=1
# docker exec does not inherit the entrypoint environment; without this the
# skills CLI writes its lock file to ~/.agents/.skill-lock.json instead.
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
SKILLS="npx -y skills@1.7.1"

add() {
  src=$1
  shift
  set -- $(printf -- '-s %s ' "$@")
  $SKILLS add "$src" "$@" -g -a claude-code -a codex -a opencode -y
}

$SKILLS add "$HERE/frontend-orchestrator" -g -a claude-code -a codex -a opencode -y

add pbakaus/impeccable impeccable
add Leonxlnx/taste-skill design-taste-frontend
add nextlevelbuilder/ui-ux-pro-max-skill ui-ux-pro-max
add anthropics/skills frontend-design
add vercel-labs/agent-browser agent-browser
add vercel-labs/agent-skills web-design-guidelines
add shadcn/ui shadcn
add emilkowalski/skills \
  animate improve-animations review-animations animation-vocabulary break-ui animate-expo
add greensock/gsap-skills \
  gsap-core gsap-react gsap-frameworks gsap-timeline gsap-scrolltrigger gsap-plugins gsap-performance gsap-utils

$SKILLS list -g
