# Repository Guidelines

## Project Structure & Module Organization
- `init.lua`: main entry point; core options, keymaps, and plugin specs live here.
- `lua/kickstart/`: reusable Kickstart modules (for example `health.lua` and plugin configs under `plugins/`).
- `lua/custom/plugins/`: local, user-specific plugin overrides/extensions (for example `harpoon.lua`, `sqls.lua`).
- `doc/`: Vim help docs (`doc/kickstart.txt`).
- `.github/workflows/`: CI checks (currently Stylua formatting validation).
- `lazy-lock.json`: plugin lockfile managed by `lazy.nvim`.

## Build, Test, and Development Commands
- `nvim`: start Neovim with this config; first run installs plugins via `lazy.nvim`.
- `nvim --headless '+checkhealth kickstart' +qa`: run Kickstart health checks in CI-friendly/headless mode.
- `stylua --check .`: verify Lua formatting (matches CI).
- `stylua .`: apply formatting fixes.
- `nvim --headless '+Lazy! sync' +qa`: sync/update plugins and lockfile non-interactively.

## Coding Style & Naming Conventions
- Lua is formatted with Stylua using `.stylua.toml` (2-space indent, 160 column width, prefer single quotes).
- Keep plugin specs grouped logically and file-scoped by feature (for example `lua/custom/plugins/<feature>.lua`).
- Use descriptive snake_case for local Lua variables/functions and clear plugin file names (`render-markdown.lua`).
- Favor small, focused config changes; avoid unrelated refactors in the same PR.

## Testing Guidelines
- There is no formal unit test suite in this repo today.
- Required checks for contributions:
  - Format check: `stylua --check .`
  - Runtime sanity: launch `nvim` and verify startup has no errors.
  - Health check: `nvim --headless '+checkhealth kickstart' +qa`
- For plugin/keymap changes, include a short manual verification note in the PR.

## Commit & Pull Request Guidelines
- Follow existing commit style: short, imperative summaries (`fix keymap jump forward`, `add harpoon mapping`).
- Keep commits scoped to one logical change.
- PRs should include:
  - what changed and why,
  - affected files/areas (for example `init.lua`, `lua/custom/plugins/*`),
  - manual validation steps and outcomes,
  - linked issue/PR when relevant.
- If behavior or UX changes are visible, add screenshots or terminal snippets where helpful.
