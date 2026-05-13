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
cmux list-workspaces     # All open workspaces
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

For naming resolution, `--cwd` semantics, and the self-closing pattern for
short-lived spawned workspaces, read
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

### Feature lifecycle slash commands

When the user starts, finishes, or abandons a feature, prefer the slash
commands over running `git worktree` / `git branch` / `git merge` by hand:

- `/cmux:start-feature <slug>` — new feature in an isolated worktree+workspace
- `/cmux:finish-feature` — merge, remove worktree, close workspace
- `/cmux:abandon-feature` — destructive; confirm first

For trigger phrasing, preconditions, and when to fall through to manual git
plumbing, read [references/feature-lifecycle.md](references/feature-lifecycle.md).

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
- **Prefer feature lifecycle slash commands** over manual git plumbing.
- **Browser split** for visual/DOM verification only. Close with
  `cmux close-surface` when done.
- **Progress bar** for tasks over ~30 seconds.
- **Notify** at genuine handoff points only — not after every step.
