# Worktree lifecycle hooks — `post-create.sh` / `pre-destroy.sh`

Read this when the user asks to set up project bootstrap for new worktrees
(install deps, start services, seed a database), tear-down for finished ones
(stop a dev server, drop a temp DB, prune containers), or when they describe
state that should exist *only inside* an isolated worktree.

These are **project-level** hooks committed to the repo under `.cmux/`. They
are not the same as the plugin's own `hooks/hooks.json`, and not the same as
Claude Code hooks in `~/.claude/settings.json`. They run only when the
`/cmux:new-workspace`, `/cmux:close-workspace`, or `/cmux:cancel-workspace`
skills operate on an isolated worktree.

## The two hooks

| File | When | cwd | On failure |
|---|---|---|---|
| `<repo>/.cmux/post-create.sh` | After `/cmux:new-workspace` creates the worktree, before Claude Code launches | New worktree | Claude Code does not launch; user fixes and retries |
| `<repo>/.cmux/pre-destroy.sh` | Before `/cmux:close-workspace` / `/cmux:cancel-workspace` removes the worktree | The worktree being destroyed | Cleanup aborts; worktree is left intact |

Both must be **executable** (`chmod +x`) and present in the repo for the
hook to run. Missing or non-executable → silently skipped.

## Environment variables

Both scripts receive the same env vars (names kept stable for backwards
compatibility with existing project scripts):

- `CMUX_FEATURE_SLUG` — the slug passed to `/cmux:new-workspace`
- `CMUX_FEATURE_BRANCH` — usually `feature/<slug>`
- `CMUX_FEATURE_WORKTREE` — absolute path to the isolated worktree
- `CMUX_MAIN_WORKTREE` — absolute path to the main worktree

## Examples

`.cmux/post-create.sh` — install deps so the worktree is usable immediately:

```bash
#!/usr/bin/env bash
set -euo pipefail
uv sync
pnpm install --frozen-lockfile
```

`.cmux/pre-destroy.sh` — tear down per-worktree containers:

```bash
#!/usr/bin/env bash
set -euo pipefail
docker compose -p "cmux-${CMUX_FEATURE_SLUG}" down -v
```

## Conventions

- Commit both files under `.cmux/` so every worktree gets the same lifecycle.
- Pair them: anything `post-create.sh` creates with side effects outside the
  worktree directory (containers, temp DBs, background processes) should be
  torn down in `pre-destroy.sh`.
- The plugin never auto-detects package managers or services — what "setup"
  and "teardown" mean is the project's call.
- `post-create.sh` runs in the new workspace's terminal, so its output is
  visible to the user. Don't suppress errors.
- Note that `.env`, `.env.local`, `.env.development`, `.env.development.local`,
  and `.envrc` are already symlinked from the main worktree by
  `/cmux:new-workspace` — `post-create.sh` does not need to copy them.
