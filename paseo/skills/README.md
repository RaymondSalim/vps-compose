# Agent skills for the paseo container

Global skills shared by Claude Code, Codex, and OpenCode inside the `paseo` container. The routing policy lives in two places: a short gate in `../AGENTS.md` (loaded into every session of all three agents) and the `frontend-orchestrator` skill here (loaded only for UI work, so backend sessions pay no context for the routing matrix).

## Layout

| Path in container | Read by | Source |
|---|---|---|
| `~/.agents/skills/<name>/` | Codex, OpenCode | real files, written by `install.sh` |
| `~/.claude/skills/<name>` | Claude Code | symlink to the `~/.agents/skills` copy |
| `/opt/paseo-skills` | `make skills` | read-only bind mount of this directory; `install.sh` installs `frontend-orchestrator` from it like any other skill |
| `~/.local/state/skills/.skill-lock.json` | skills CLI | source repo and folder hash per installed skill |

Nothing is placed in `~/.codex/skills`: Codex scans both that directory and `~/.agents/skills` and lists real copies twice. OpenCode scans both `~/.claude/skills` and `~/.agents/skills`, dedupes by name, and logs a warning for the paseo skills (which paseo copies to both); that warning is harmless.

## Installed

| Skill | Source | License | Role |
|---|---|---|---|
| `frontend-orchestrator` | this directory | (repo) | Task classification and routing |
| `impeccable` | pbakaus/impeccable | Apache-2.0 | Product UI build and refinement (`critique`, `audit`, `polish`, `layout`, `typeset`, `harden`, ...) |
| `design-taste-frontend` | Leonxlnx/taste-skill | MIT | Landing pages, portfolios |
| `ui-ux-pro-max` | nextlevelbuilder/ui-ux-pro-max-skill | MIT | Design-system search (styles, palettes, type); needs `python3` |
| `frontend-design` | anthropics/skills | Apache-2.0 | Lightweight aesthetic direction |
| `web-design-guidelines` | vercel-labs/agent-skills | MIT | Final UI review; fetches rules from vercel-labs/web-interface-guidelines `main` at run time |
| `shadcn` | shadcn/ui | MIT | shadcn projects and registries |
| `animate`, `improve-animations`, `review-animations`, `animation-vocabulary`, `break-ui`, `animate-expo` | emilkowalski/skills | MIT | Motion build/audit/review, edge-case stress testing, Expo motion |
| `gsap-core`, `gsap-react`, `gsap-frameworks`, `gsap-timeline`, `gsap-scrolltrigger`, `gsap-plugins`, `gsap-performance`, `gsap-utils` | greensock/gsap-skills | MIT | GSAP, gated by the orchestrator to projects or effects that need it |

## Deliberately not installed

| Resource | Reason |
|---|---|
| Impeccable hooks (`npx impeccable install`, plugin hooks) | Hooks run outside tool approval and download a binary. The skill itself still downloads a checksummed binary to `~/.impeccable/` on first use. Enable per project with `impeccable hooks on` if wanted. |
| UI/UX Pro Max siblings (`design`, `design-system`, `brand`, `slides`, `banner-design`, `ui-styling`) and the `uipro` CLI | Generic names collide with other skills (`design-system` also collides with TypeUI); `design` calls paid image APIs; `uipro init` always installs all siblings. |
| Other Taste variants (12) | Overlapping triggers with `design-taste-frontend`; style presets can be added individually. |
| Emil `prototype`, `pick-ui-library` | Rely on `disable-model-invocation`, which Codex and OpenCode ignore, so they would auto-trigger there; `pick-ui-library` contradicts the component policy. |
| Emil `emil-design-eng`, `apple-design`, `mobile-native`, `ask-sonner`, `find-animation-opportunities`, `write-swift` | No trigger text or overlap with installed skills; `write-swift` is off-topic. Add if a real need appears. |
| Other vercel-labs skills | Deployment and React performance, outside UI/UX scope. |
| TypeUI | Its design languages are pulled per project (`npx typeui.sh pull <slug>`), which writes a skill named `design-system`; global install would collide. Hosted MCP and Pro need an account. |
| Cult UI, Watermelon UI, Magic UI | Component registries, not skills. Reached through `npx shadcn@latest view|add @cult-ui/... @watermelon/... @magicui/...` (see `frontend-orchestrator/references/components.md`). |
| shadcn MCP, Magic UI MCP, Watermelon MCP | Redundant with the shadcn CLI; shadcn MCP is per-project and adds a devDependency. |
| 21st.dev | API key, paid tiers, sends prompts and project context to 21st.dev. |
| Spline | External editor with an account; desktop-app MCP (macOS/Windows) rewrites agent configs. Use `@splinetool/react-spline` per project. |

## Fresh deployment

On a new host, after cloning and creating `.env`:

```sh
make up       # builds the image (includes python3) and starts the container
make skills   # installs the skill set into the persisted home
```

`make up` alone does not install skills. Nothing is bind-mounted inside `/home/paseo/.agents` or `/home/paseo/.claude/skills`, because Docker would create those mount-point directories as root and the entrypoint only chowns `$HOME`, `.claude`, `.codex`, `.config`, and the XDG directories, which would leave the skill directories unwritable for the `paseo` user.

## Maintenance

All commands run on the host from `paseo/`.

```sh
make skills          # install or reinstall the set (idempotent)
make skills-list     # list global skills known to the skills CLI
make skills-update   # update every skill installed by the CLI to upstream HEAD
```

Inside the container (`make shell`):

```sh
export DISABLE_TELEMETRY=1
npx -y skills@1.7.1 add <owner/repo> -s <name> -g -a claude-code -a codex -a opencode -y   # add
npx -y skills@1.7.1 remove <name> -g -y                                                    # remove
```

Add a skill by appending it to `install.sh` and to the tables above, then reference its exact name in `frontend-orchestrator/SKILL.md` if it should be routed. Remove it from all three places. After editing `frontend-orchestrator`, run `make skills` to copy the new version into the home directory.

The skills CLI cannot pin a git ref; `update` tracks upstream HEAD. Before updating, review upstream changes for the skills that run code (`impeccable` launcher, `ui-ux-pro-max` scripts). The lock file's `skillFolderHash` shows which version is installed.

## Troubleshooting discovery

```sh
ls -la ~/.claude/skills ~/.agents/skills           # symlinks must resolve
opencode debug skill                                # OpenCode's resolved skill list and locations
codex debug prompt-input | grep -o '<skills_instructions>' # Codex prompt includes a skills block
```

In Claude Code, run `/skills` or ask for the skill list. A skill missing only in Claude Code usually means a broken symlink in `~/.claude/skills`. A skill listed twice in Codex means a copy exists in `~/.codex/skills`. `ui-ux-pro-max` search fails without `python3` (installed by the Dockerfile; rebuild with `make update`).

## Status and open items (2026-10-08)

The skills are installed in the persisted home and are discovered once each by all three agents (`opencode debug skill`, `codex debug prompt-input`, Claude Code skill list). Routing was tested against throwaway fixture projects (landing page, existing dashboard with `DESIGN.md`, Motion dropdown, CSS footer bug, Express backend). Claude Code and OpenCode chose the expected skills in all five cases. Codex loaded `frontend-orchestrator` first for the four UI cases and skipped it for the backend case, but every shell command then failed in its sandbox, so its second-stage selection is unverified.

Open items:

- The `AGENTS.md` routing section and the `/opt/paseo-skills` mount take effect only after the container is recreated from this compose file (`make up`). A container started from an older compose file reads a different policy file.
- `make skills` (the `docker exec` path) has not been run end to end; `install.sh` itself was run in the container and against an empty `HOME`.
- `python3` for `ui-ux-pro-max` arrives with the next image build (`make update`).
- Codex's `read-only`/`workspace-write` sandbox cannot start in this container (`bwrap: No permissions to create a new namespace`), independent of skills. It needs either unprivileged user namespaces on the host or a deliberate sandbox decision for Codex.
- In OpenCode, the superpowers plugin injects `brainstorming` into every session, and it also ran in the landing-page and backend tests. It did not displace the UI routing.
