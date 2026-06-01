# Spawning workspaces — naming, `--cwd`, self-closing

Read this when opening a workspace from another workspace (parallel work, code
review, queue worker, one-shot pipeline).

## Naming convention — prefix with the caller

Always name the new workspace `<caller-workspace-name>-<task-slug>`. The
parent context must be visible in the sidebar; never use a bare task slug.

```bash
# Resolve the *caller's* workspace name (the one this Claude session runs in —
# not necessarily the one the user is focused on).
CURRENT_WS_REF=$(cmux identify --json | jq -r '.caller.workspace_ref')
CURRENT_WS=$(cmux workspace list --json \
  | jq -r --arg ref "$CURRENT_WS_REF" '.workspaces[] | select(.ref == $ref) | .title')

# Fallback if cmux didn't respond or parsing failed
[ -z "$CURRENT_WS" ] && CURRENT_WS=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")

cmux workspace create \
  --name "${CURRENT_WS}-code-review" \
  --command "claude 'Review the changes on main since <commit>...'" \
  --focus true
```

Pass `--name` directly at creation time. Don't create then rename.

## `--cwd` semantics

`--cwd <path>` sets the actual working directory of the spawned shell — not
just a hint. Any script invoked from that shell with a relative path resolves
against `<path>`, not against the parent workspace's CWD. When the spawn
prompt tells the new Claude to run things "from the repo root", make sure
that's where `--cwd` points; otherwise feed absolute paths into the prompt so
the spawned session can't get them wrong.

## Grouping related spawns

When one effort fans out into several child workspaces (parallel reviews,
feature slices, a queue of one-shot jobs), collapse them under a single sidebar
header so the parent context stays legible. A group is owned by an **anchor**
workspace — the group header *is* the anchor's sidebar row — and closing the
anchor dissolves the group while preserving its members.

```bash
# Create a group (a fresh anchor workspace becomes its header) from existing
# workspaces. Prints: OK workspace_group:N
GROUP=$(cmux workspace-group create --name "${CURRENT_WS}-review" \
  --from workspace:3,workspace:4 | awk '{print $2}')

# Fold another existing workspace in later
cmux workspace-group add --group "$GROUP" --workspace workspace:7
```

`cmux workspace-group new-workspace "$GROUP"` spawns a workspace straight into
the group. To take a group apart, prefer `cmux workspace-group ungroup <group>`
— it dissolves the group but keeps every member as an ungrouped workspace.
`delete` also closes every member, so never point it at a group that holds the
workspace you are running in.

Run `cmux workspace-group --help` for collapse/expand, pin, rename, set-anchor,
icon/color, and placement controls.

## Self-closing spawned workspace

When the spawned workspace should live only as long as one task, the spawned
Claude needs to close its own workspace at the end. Two rules:

1. **Don't persist the workspace ref to a file inside `--cwd`.** The ref is
   already available inside the spawned shell:
   - `$CMUX_WORKSPACE_ID` — the UUID
   - `cmux identify --json | jq -r .caller.workspace_ref` — the short form
     (`workspace:N`)

   Both forms are accepted by `cmux workspace close`.

2. **Close last.** `cmux workspace close "$CMUX_WORKSPACE_ID"`
   tears down the PTY, which kills Claude Code. Run it as the final
   subprocess call after every other cleanup step, and treat its failure as
   best-effort.

End-of-task hook for a spawned session:

```bash
cmux log --level success --source "<skill>" "done"
cmux clear-progress
cmux workspace close "$CMUX_WORKSPACE_ID" || true
```
