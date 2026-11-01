---
name: frontend-orchestrator
description: Routing policy for frontend UI/UX work. Load this first, before any other design, animation, or UI-review skill, whenever a task builds, redesigns, refines, animates, or reviews something users see (pages, components, layout, styling, motion, design systems). It classifies the task and names the smallest set of skills to load. Not for backend, API, database, infrastructure, CLI, or documentation tasks.
---

# Frontend orchestrator

Classify the task, inspect the project, pick the smallest useful skill set, then load only those skills. Do not load skills "just in case". State the chosen route in one line before starting, e.g. `Route: existing-UI refinement → impeccable (layout), review with web-design-guidelines`.

## 1. Precedence

1. Explicit user requirements and agent-level instructions.
2. The project's existing architecture and documented design decisions: `DESIGN.md`, `PRODUCT.md`, `design-system/*/MASTER.md`, tokens, theme files, `components.json`, existing components.
3. Project `AGENTS.md` / `CLAUDE.md`.
4. This routing policy.
5. Generic recommendations inside individual skills (default stacks, fonts, banned patterns, "recommend library X").

When a skill's advice conflicts with a higher level, follow the higher level and say so in one sentence. Never override a project convention to satisfy a skill's aesthetic preference. Skills that say "use Tailwind v4", "recommend GSAP", or "install package X" are suggestions at level 5.

## 2. Inspect the project first (cheap, read-only)

Before choosing skills, check: `package.json` dependencies (framework, `tailwindcss` version, `motion`/`framer-motion`, `gsap`, `react-native`/`expo`, UI kits), `components.json` (shadcn), existing component directory, `DESIGN.md` / `PRODUCT.md` / `design-system/`, `.impeccable/`, Playwright or Storybook config. These facts decide the route; the task wording alone does not.

## 3. Routing matrix

| Task intent | Primary (one) | Supporting, only when the need appears | Final check |
|---|---|---|---|
| A. New marketing site, landing page, portfolio, campaign page | `design-taste-frontend` | `ui-ux-pro-max` search for palette/type options when no brand exists; component registries (see `references/components.md`); `animate` for motion | `web-design-guidelines` + rendered check |
| B. New app UI: SaaS screens, dashboards, admin, settings, forms | `impeccable` (Operate mode; `shape` to plan) | `ui-ux-pro-max` when the project has no design system; `shadcn` when the project uses or adopts shadcn | `web-design-guidelines` + rendered check |
| C. Refining existing UI | `impeccable` with the narrowest command: `critique`, `audit`, `polish`, `layout`, `typeset`, `clarify`, `distill`, `harden`, `adapt`, `onboard`, `optimize` | `break-ui` for data-heavy components | `web-design-guidelines` if the change was substantial |
| D. Creating or formalising a design system | `ui-ux-pro-max` (`--design-system`, no `--persist` unless the project already uses `design-system/`) | `impeccable document`/`extract` to derive from existing code; TypeUI pull when a named design language is wanted (see 5) | Write approved decisions to `DESIGN.md` |
| E. Open creative exploration | Exactly one of: `design-taste-frontend` (bold, anti-template marketing/portfolio), `frontend-design` (lightweight aesthetic direction for any surface), `impeccable` (product UI, `bolder`/`delight`/`overdrive`, live variants), TypeUI design language (a named style) | none simultaneously | Rendered check |
| F. Animation and micro-interactions (web) | `animate` (build), `review-animations` (critique a diff), `improve-animations` (codebase audit, read-only) | GSAP skills only under the gate in 4; `animation-vocabulary` to name an effect | Reduced-motion and performance check |
| F'. Animation in React Native / Expo | `animate-expo` | none | Device/simulator check if available |
| G. UI quality review | `web-design-guidelines` | `impeccable audit` for depth; `review-animations` for motion; `break-ui` for edge-case data | Rendered check |
| H. Small CSS bug, single-element fix, copy tweak | none, fix directly | at most one targeted skill if the fix needs design judgment (e.g. `impeccable layout`) | Render the affected view |
| I. Non-UI work | none | none | none |

Redesign only when the user asks for it. "Improve", "fix", "clean up", and "make it look better" on an existing UI are route C (refinement preserves identity, copy, and behaviour), not A or E.

## 4. Conflict rules

- One creative authority per task. `design-taste-frontend`, `frontend-design`, and `impeccable` must not direct the same work simultaneously. Sequential use is fine when roles differ: build with one, then `impeccable critique`/`audit` or `web-design-guidelines` as reviewer. Reviewers report; they do not restart the design.
- `design-taste-frontend` is for landing pages, portfolios, and redesigns of those. Do not use it for dashboards, data tables, or multi-step product UI.
- Animation library: use what the project already depends on. If `motion`/`framer-motion` is present, stay with it; if CSS transitions suffice, use CSS. Load `gsap-*` skills only when `gsap` is already a dependency, the user asks for GSAP, or the effect needs scroll scrubbing/pinning, SplitText, or long choreographed timelines that the existing tool cannot express cleanly. Then load only the matching one (`gsap-react`, `gsap-scrolltrigger`, `gsap-timeline`, ...), not all eight.
- `impeccable animate` and `animate` overlap. Inside an Impeccable-driven task, Impeccable's command may handle incidental motion; for motion-first tasks use `animate`.
- One design document owner per project. If `DESIGN.md` exists, it is canonical; update it, do not regenerate it. If only `design-system/<slug>/MASTER.md` exists, treat that as canonical instead. For a new project, write `DESIGN.md` at the root. Never create a second competing design doc. Do not regenerate the design system for ordinary feature work.
- `ui-ux-pro-max` results are candidates. Existing tokens and brand assets beat them.

## 5. Skill-specific notes

- `ui-ux-pro-max`: its commands reference `${CLAUDE_PLUGIN_ROOT}/.claude/skills/ui-ux-pro-max/scripts/search.py`. Outside the Claude plugin that variable is unset; use `<this skill's directory>/scripts/search.py` (installed at `~/.agents/skills/ui-ux-pro-max/`). It needs `python3`. If `python3` is missing, read its `data/` CSVs and `references/` directly and say the search script was unavailable.
- `impeccable`: runs `<skill dir>/scripts/impeccable context`, which downloads a checksummed binary to `~/.impeccable/` on first use. Its detector hooks are intentionally not installed globally; do not run `impeccable hooks on` or `npx impeccable install` unless the user asks. `init` writes `PRODUCT.md`, `DESIGN.md`, `.impeccable/` in the project; only run it for new work or when the user agrees.
- `web-design-guidelines`: fetches its rule set from `https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md` at run time. If the fetch is unavailable or denied, fall back to `impeccable audit` and say so.
- `shadcn`: applies when `components.json` exists or the user/route chooses shadcn for a new React app. It runs `npx shadcn@latest info --json`; do not run `shadcn init` in an existing project without agreement.
- TypeUI: no global skill. For a named design language, run in the project `npx typeui.sh list`, then `npx typeui.sh pull <slug>` (writes a project skill named `design-system` and/or `DESIGN.md` with `--format design`). Check for an existing `DESIGN.md` first; pulling overwrites. The hosted MCP and Pro tier require a TypeUI account and are not configured.

## 6. Components

Follow `references/components.md` when a task needs a component that the project does not already have. Read it only then.

## 7. Quality assurance

Written guidelines are not a substitute for looking at the result. After substantial UI changes:

1. Run the project's own lint, typecheck, and tests.
2. Render the page: use `agent-browser` (`agent-browser open <url> && agent-browser screenshot`), the project's Playwright/Storybook setup, or an available browser tool. Capture desktop and mobile widths. If no rendering is possible, say so explicitly; do not claim visual verification.
3. Check keyboard navigation and visible focus, semantic structure and labels, contrast, responsive layout, loading/empty/error states, and `prefers-reduced-motion`.
4. Run `web-design-guidelines` on the changed files.

Keep QA bounded: one inspection pass, one batch of fixes, at most one confirmation pass.

## 8. When a skill is unavailable

If a named skill is not installed or fails to load, continue with the next option in the same row, then with general knowledge, and state which skill was missing. Do not install skills or MCP servers mid-task without asking.
