---
name: cmux
description: Use cmux terminal features when running inside cmux. Detected via CMUX_WORKSPACE_ID environment variable. Apply proactively for parallel work (worktrees, sub-agents, long tasks), browser-based testing, sidebar progress reporting, and attention notifications. Do NOT apply when not inside cmux.
---

# cmux Terminal Integration

cmux is a native macOS terminal built for AI coding agents. When running inside
it you have a CLI that controls workspace layout, reports progress in the
sidebar, drives a scriptable browser pane, and sends notifications.

## Detection — always run first

```bash
[ -n "$CMUX_WORKSPACE_ID" ] \
  && [ -n "$CMUX_SURFACE_ID" ] \
  && [ -S "${CMUX_SOCKET_PATH:-$HOME/Library/Application Support/cmux/cmux.sock}" ] \
  && command -v cmux &>/dev/null
```

If any check fails → skip all cmux commands silently. Never error because cmux
is absent.

Orient yourself:

```bash
cmux identify --json     # Current window / workspace / pane / surface IDs
cmux workspace list      # All open workspaces
```

## Hierarchy

```
Window
  └── Workspace  (sidebar tab — one per project or parallel task)
        └── Pane  (split region — horizontal or vertical)
              └── Surface  (terminal or browser session)
```

Refer to them as `workspace:1`, `pane:2`, `surface:3` in CLI commands.

---

## When to use each feature

### Spawn a workspace — parallel and isolated work

**Trigger:** about to create a git worktree, launch an independent sub-agent
on a separate branch, or start a task genuinely isolated from the current
context. One workspace per isolated thread — not per subtask.

**Always name it `<caller-workspace-name>-<task-slug>`.** The parent context
must be visible in the sidebar; never use a bare task slug.

For naming resolution, `--cwd` semantics, grouping a fan-out of spawns under
one sidebar header, and the self-closing pattern for short-lived spawned
workspaces, read
[references/spawning-workspaces.md](references/spawning-workspaces.md).

### Browser split — visual and DOM verification

**Trigger:** verify a UI, test a dev server, check rendered output, debug
CSS, interact with a running app.

```bash
BROWSER_OUT=$(cmux browser open-split "http://localhost:3000")
BROWSER_SURFACE=$(echo "$BROWSER_OUT" | sed -E 's/.*surface=(surface:[0-9]+).*/\1/')
cmux browser "$BROWSER_SURFACE" snapshot --compact
# ... interact ...
cmux close-surface --surface "$BROWSER_SURFACE"
```

For the full browser command surface (wait, eval, find, console, errors,
cookies, viewport, network, …) read
[references/browser-automation.md](references/browser-automation.md).

### Sidebar progress — long-running tasks

**Trigger:** any task that will take more than ~30 seconds.

```bash
cmux log --level info --source "claude" "Starting: full test suite..."
cmux set-progress 0.0
# ... work ...
cmux set-progress 0.75
cmux log --level progress --source "claude" "Tests: 112/150 passing"
# ... done ...
cmux set-progress 1.0
cmux log --level success --source "claude" "All 150 tests passed"
cmux clear-progress
```

Log levels: `info` · `progress` · `success` · `warning` · `error`.

### Notifications — genuine handoff points

**Trigger:** a long sub-agent task finished and needs human review; you've
reached a checkpoint and are waiting for human input. NOT after every step.

```bash
cmux notify --title "Claude Code" --body "Sub-agent finished: auth feature ready for review"
cmux trigger-flash    # Flash the pane ring for visual attention
```

### Isolated workspace lifecycle skills

When the user starts, lands, or discards a piece of isolated work (a feature,
a code review, a spike, a refactor), prefer these skills over running
`git worktree` / `git branch` / `git merge` by hand:

- `/cmux:new-workspace <slug>` — open an isolated worktree+workspace, grouped under the origin
- `/cmux:close-workspace` — merge, remove worktree, close workspace; dissolve the group when it's the last slice
- `/cmux:cancel-workspace` — destructive; confirm first; same group cleanup as close

For trigger phrasing, preconditions, and when to fall through to manual git
plumbing, read [references/workspace-lifecycle.md](references/workspace-lifecycle.md).

Projects can also install optional **per-worktree lifecycle hooks**
(`.cmux/post-create.sh` after creation, `.cmux/pre-destroy.sh` before
removal) to bootstrap or tear down state tied to an isolated worktree —
installing deps, starting containers, dropping temp databases, etc. For
the file layout, env vars (`CMUX_FEATURE_SLUG`, `CMUX_FEATURE_BRANCH`,
`CMUX_FEATURE_WORKTREE`, `CMUX_MAIN_WORKTREE`), and failure semantics,
read [references/worktree-lifecycle-hooks.md](references/worktree-lifecycle-hooks.md).

### Open files or URLs — surface an artifact to the user

**Trigger:** you've produced something the user should look at — a generated
report, a screenshot, a markdown file, a deployed URL — and you want it in
front of them without taking over the current pane.

```bash
cmux open ./report.md              # Markdown → live-reloading markdown preview tab
cmux open ./out.png ./diagram.pdf  # Other files → file preview tabs (one per path)
cmux open https://staging.app/...  # URL → browser surface
```

Targeting flags (`--workspace`, `--surface`, `--pane`, `--window`,
`--focus|--no-focus`) let you route the open into an existing surface or
keep focus where it is. Use `--no-focus` for ambient updates that should
not interrupt the user.

`cmux open` is the right tool for one-shot artifact display. For scripted
DOM interaction or visual verification of a dev server, use
`cmux browser open-split` instead (see above) — it returns a surface ref
you can drive further.

To show the user a **rendered diff** rather than dumping a patch into the
terminal, use `cmux diff` — it renders a unified diff in a browser split:

```bash
cmux diff --branch              # Current branch vs its merge base
cmux diff --unstaged            # Working-tree changes
cmux diff --staged              # Staged changes
cmux diff --last-turn           # Changes since this surface's last agent-turn baseline
git diff | cmux diff            # Or pipe any patch in via stdin
```

`--last-turn` is the agent-friendly source: it shows exactly what changed
since your last turn's baseline, so you can surface your own edits without
diffing branches by hand. Tune presentation with `--layout split|unified`
and `--font-size <points>`.

Like the browser split, it defaults to `--no-focus`; pass `--focus true` to
bring it forward.

### Superpowers plugin

When the Superpowers plugin is active, certain of its workflows pair
naturally with cmux actions (worktrees, sub-agent progress, branch-finish
notifications). See
[references/superpowers-integration.md](references/superpowers-integration.md).

---

## Discoverability

The commands above cover 95% of cases. For anything else, ask cmux directly:

```bash
cmux --help                  # Full command list
cmux <command> --help        # Per-command flags (e.g. cmux browser --help)
cmux docs <topic>            # Fetchable URLs for in-depth docs
                             # topics: settings · shortcuts · api · browser · agents · dock
cmux capabilities            # JSON list of every RPC method the daemon exposes
```

---

## Rules

- **Always detect** before using. Never assume you're in cmux.
- **Never crash** if cmux is absent. All cmux calls are best-effort, exit 0.
- **Spawn a workspace** for parallel/isolated work only — not for subtasks.
  Name as `<caller-workspace-name>-<task-slug>`, never a bare slug.
- **Prefer the workspace lifecycle skills** over manual git plumbing.
- **Browser split** for visual/DOM verification only. Close with
  `cmux close-surface` when done.
- **Progress bar** for tasks over ~30 seconds.
- **Notify** at genuine handoff points only — not after every step.
