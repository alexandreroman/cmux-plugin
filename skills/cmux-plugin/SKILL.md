---
name: cmux-plugin
description: Use cmux terminal features when running inside cmux. Detected via CMUX_WORKSPACE_ID environment variable. Apply proactively for parallel work (worktrees, sub-agents, long tasks), browser-based testing, sidebar progress reporting, and attention notifications. Do NOT apply when not inside cmux.
---

# cmux Terminal Integration

cmux is a native macOS terminal built for AI coding agents. When running inside it
you have access to a CLI that lets you control workspace layout, report progress in
the sidebar, open a scriptable browser pane, and send notifications.

## Detection — Always Check First

Before using any cmux feature, confirm you are inside cmux:

```bash
[ -n "$CMUX_WORKSPACE_ID" ] \
  && [ -n "$CMUX_SURFACE_ID" ] \
  && [ -S "${CMUX_SOCKET_PATH:-/tmp/cmux.sock}" ] \
  && command -v cmux &>/dev/null
```

If any check fails → skip all cmux commands silently. Never error because cmux is absent.

Quick orientation when inside cmux:

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

## When to Use Each Feature

### New workspace — parallel and isolated work

**Trigger:** About to create a git worktree, launch an independent sub-agent on a
separate branch, or start a task that is genuinely isolated from the current context.

**Naming convention — always:** `<current-workspace-name>-<task-slug>`. Prefix
the new workspace with the current one so the parent context is obvious in the
sidebar. Example: from workspace `durable-money`, opening a code review →
`durable-money-code-review`. From `cmux-plugin`, a long migration task →
`cmux-plugin-jpa-migration`. The task slug is short, lowercase, dash-separated.

```bash
# Resolve the *caller's* workspace name (the one this Claude session runs in —
# not necessarily the one the user is focused on, which is what `*` marks).
CURRENT_WS_REF=$(cmux identify --json | jq -r '.caller.workspace_ref')
CURRENT_WS=$(cmux list-workspaces \
  | sed -E 's/^[* ] +//' \
  | awk -F'  +' -v ref="$CURRENT_WS_REF" '$1 == ref { print $2 }')

# Create the new workspace with the prefixed name in one shot — pass --name
# directly instead of renaming after creation.
cmux new-workspace \
  --name "${CURRENT_WS}-code-review" \
  --command "claude 'Review the changes on main since <commit>...'" \
  --focus true
```

If `$CURRENT_WS` is empty (cmux not responding, parsing failed), fall back to
`$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")`. Never use a
bare task slug like just `code-review` — the parent context must be visible in
the sidebar.

**Restraint:** One workspace per isolated worktree or major parallel thread.
Do NOT open a new workspace for every subtask within a single feature.

---

### Browser split — visual and DOM verification

**Trigger:** Need to verify a UI, test a dev server, check rendered output,
debug a CSS issue, or interact with a running app.

```bash
# Open a browser to the right of the current terminal pane
cmux browser surface:$CMUX_SURFACE_ID open-split --direction right
sleep 1

# Navigate
cmux browser surface:2 navigate "http://localhost:3000"

# Inspect and interact
cmux browser surface:2 snapshot --compact                    # Read DOM
cmux browser surface:2 get text ".error-message"            # Extract text
cmux browser surface:2 click "button.submit"                # Click element
cmux browser surface:2 fill "#search" "query"               # Type into field
cmux browser surface:2 screenshot --out /tmp/verify.png     # Capture screenshot
```

**Restraint:** Only open a browser split when visual/DOM verification is genuinely
needed. Close the surface when done — don't leave idle browser panes open.

---

### Sidebar progress — long-running tasks

**Trigger:** Any task that will take more than ~30 seconds. Set a bar at the start,
update it as stages complete, clear it when done.

```bash
cmux log --level info --source "claude" "Starting: full test suite..."
cmux set-progress 0.0

# Update as work proceeds
cmux set-progress 0.25
cmux log --level progress --source "claude" "Tests: 40/150 passing"

cmux set-progress 0.75
cmux log --level progress --source "claude" "Tests: 112/150 passing"

# Completion
cmux set-progress 1.0
cmux log --level success --source "claude" "All 150 tests passed ✓"
cmux clear-progress
```

Sidebar log levels: `info` · `progress` · `success` · `warning` · `error`

---

### Feature lifecycle — start / finish / abandon

**Trigger — `/cmux:start-feature <slug>`:** As soon as the user describes a new
feature or substantive new piece of work ("new feature", "let's add X", "build
a Y", "implement Z", "I want to create…"), and you are in the main worktree of
a cmux-enabled repo, prefer this command over editing the main worktree
directly. It creates a `feature/<slug>` worktree under `.worktrees/<slug>` and
opens a new cmux workspace named `<repo-basename>-<slug>` with Claude Code
running inside it. Skip for trivial fixes, tiny doc tweaks, or when the user is
already inside a feature worktree.

**Trigger — `/cmux:finish-feature`:** When work inside a feature worktree is
complete and the user signals integration ("merge it", "ship it", "this is
done", "wrap up", or tests/checks pass and they want to land it). Merges into
the base branch (fast-forward when possible), removes the worktree and branch,
and closes this cmux workspace.

**Trigger — `/cmux:abandon-feature`:** When the user wants to throw the feature
away ("abandon", "discard", "scrap this", "start over", "this isn't working").
Destructive — removes the worktree, force-deletes the branch, and closes the
workspace. Always confirm via `AskUserQuestion` before running, even in auto
mode.

**Restraint:** All three commands assume the worktree layout produced by
`/cmux:start-feature`. If the user is on a feature branch they made by hand
(no `.worktrees/<slug>` worktree, or no matching cmux workspace), suggest the
matching slash command but verify the preconditions in the command file before
invoking — don't try to retrofit the cleanup logic onto an unrelated branch.

---

### Notifications — genuine handoff points

**Trigger:** A long sub-agent task has finished and needs human review.
You have reached a checkpoint and are waiting for human input.

```bash
cmux notify --title "Claude Code" --body "Sub-agent finished: auth feature ready for review"
cmux notify --title "Claude Code" --subtitle "Checkpoint" --body "Plan approved — ready to execute"

# Flash the pane ring to grab visual attention
cmux trigger-flash
```

**Restraint:** Do NOT notify after every small step. Reserve notifications for real
handoff moments where you genuinely need the human's eyes.

---

## Superpowers Plugin Integration

When the Superpowers plugin is active and its workflows trigger:

| Superpowers event | cmux action |
|---|---|
| `using-git-worktrees` activates | Open new workspace named after the branch |
| `subagent-driven-development` running | Set + update progress bar per task completed |
| Each sub-agent task completes | `cmux log --level success` with task name |
| `finishing-a-development-branch` activates | `cmux notify` — human review needed |

This gives ambient awareness of parallel work across the sidebar without the human
needing to actively watch any terminal.

---

## Full CLI Reference

```bash
# Workspace
cmux list-workspaces
cmux new-workspace [--command "<cmd>"]
cmux rename-workspace [--workspace <id>] "new-name"
cmux select-workspace --workspace <id>
cmux close-workspace --workspace <id>

# Panes and surfaces
cmux list-panes [--workspace <id>]
cmux new-pane [--direction right|left|up|down] [--workspace <id>]
cmux list-pane-surfaces [--workspace <id>] [--pane <id>]
cmux focus-pane --pane <id> [--workspace <id>]

# Browser
cmux browser [--surface <id>] open-split [url]
cmux browser [--surface <id>] navigate "<url>"
cmux browser [--surface <id>] snapshot [--compact]
cmux browser [--surface <id>] get text "<css-selector>"
cmux browser [--surface <id>] click "<css-selector>"
cmux browser [--surface <id>] fill "<css-selector>" "<value>"

# Sidebar
cmux log [--level info|progress|success|warning|error] [--source "<label>"] [--workspace <id>] "<message>"
cmux set-progress <0.0–1.0> [--label "<text>"] [--workspace <id>]
cmux clear-progress [--workspace <id>]
cmux list-log [--limit <n>] [--workspace <id>]
cmux clear-log [--workspace <id>]

# Sidebar status metadata
cmux set-status <key> <value> [--icon <name>] [--color <#hex>] [--workspace <id>]
cmux clear-status <key> [--workspace <id>]
cmux list-status [--workspace <id>]
cmux sidebar-state [--workspace <id>]

# Notifications
cmux notify --title "<title>" [--body "<body>"] [--subtitle "<subtitle>"] [--workspace <id>]
cmux trigger-flash [--workspace <id>] [--surface <id>]

# System
cmux ping
cmux identify --json
cmux capabilities
```

---

## Rules

- **Always detect** before using. Never assume you're in cmux.
- **New workspace** for parallel/isolated work only. Not for subtasks. Name as
  `<current-workspace-name>-<task-slug>` — never a bare task slug.
- **Feature lifecycle commands** — when the user starts, finishes, or abandons
  a feature, prefer `/cmux:start-feature`, `/cmux:finish-feature`, and
  `/cmux:abandon-feature` over running `git worktree` / `git branch` /
  `git merge` by hand.
- **Browser split** for visual/DOM verification only. Close when done.
- **Progress bar** for tasks over ~30 seconds.
- **Notify** at genuine handoff points only — not after every step.
- **Never crash** if cmux is absent. All cmux calls are best-effort, exit 0.
