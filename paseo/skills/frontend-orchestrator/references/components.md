# Component sourcing

Read when a task needs a component the project does not already have.

## Order of preference

1. Reuse or extend the project's existing components.
2. Use the project's established UI framework or kit (whatever `package.json` shows).
3. shadcn/ui for standard React application primitives (dialogs, menus, forms, tables) when the project is React + Tailwind and either already has `components.json` or the user agrees to adopt it. Use the `shadcn` skill.
4. Cult UI for distinctive interactive pieces (expressive buttons, cards, text effects) on marketing surfaces.
5. Watermelon UI for blocks and layouts (sections, disclosures, menus).
6. Magic UI for animated marketing components; 21st.dev only if the above are insufficient and the user has an account.
7. Spline only when interactive 3D materially improves the experience and the user can supply a scene.

Treat this as a default order, not a mandate: choose by fit with the project's typography, spacing, colour tokens, accessibility, dependencies, and interaction model.

## Using the registries

Cult UI, Watermelon UI, and Magic UI are shadcn-compatible registries listed in shadcn's built-in directory, so the namespaces resolve without configuration. Inspect before adding:

```sh
npx shadcn@latest search @cult-ui --query card
npx shadcn@latest view @cult-ui/<item>
npx shadcn@latest add @cult-ui/<item>
npx shadcn@latest view @watermelon/<item>     # https://registry.watermelon.sh/r/{name}.json
npx shadcn@latest view @magicui/<item>        # https://magicui.design/r/{name}
```

`search` and `view` work in any directory and print the item's files and dependencies as JSON. `add` needs a shadcn-initialised project (`components.json`); in a project without one, use `view` output to port the component by hand into the project's conventions instead of running `shadcn init`.

`add` writes files into the project, may add npm dependencies, and may add the namespace to `components.json`. Before adding:

- `view` the item and read every file it will write and every dependency it declares.
- Reject items that pull in a new animation or styling library the project does not use, unless the user accepts that.
- After adding, align the component with project tokens (colours, radius, spacing, fonts) and fix accessibility gaps (labels, focus, keyboard, reduced motion).

Do not mix several registries in one view without checking that typography, spacing, colours, and motion stay consistent.

## Not configured, and why

- shadcn MCP server: per-project only (`npx shadcn@latest mcp init --client claude|codex|opencode`, which also adds a devDependency). The CLI `search`/`view` commands above cover the same lookups.
- Magic UI MCP (`@magicuidesign/mcp`): duplicates `npx shadcn view @magicui/...`.
- Watermelon hosted MCP (`https://mcp.watermelon.sh/mcp`): third-party server sees queries; the registry is reachable through the CLI.
- 21st.dev (`npx @21st-dev/cli@latest init --client <agent>`): requires an API key, paid tiers, and sends prompts and project context to 21st.dev. Unauthenticated registry fetches return 403. Ask the user before using.
- Spline: authoring requires a Spline account and the editor; code integration is `npm install @splinetool/react-spline @splinetool/runtime` with a scene URL exported from the editor. `@splinetool/runtime` is closed source. The Spline desktop app's MCP rewrites agent configs on launch.
