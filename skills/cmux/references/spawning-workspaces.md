# Spawning workspaces — naming, `--cwd`, self-closing

Read this when opening a workspace from another workspace (parallel work, code
review, queue worker, one-shot pipeline).

## Naming convention — prefix with the caller

Always name the new workspace `<caller-workspace-name>-<task-slug>`. The
parent context must be visible in the sidebar; never use a bare task slug.

```bash
# Resolve the *caller's* workspace name (the one this Claude session runs in —
# not necessarily the one the user is focused on, which is what `*` marks).
CURRENT_WS_REF=$(cmux identify --json | jq -r '.caller.workspace_ref')
CURRENT_WS=$(cmux list-workspaces \
  | sed -E 's/^[* ] +//' \
  | awk -F'  +' -v ref="$CURRENT_WS_REF" '$1 == ref { print $2 }')

# Fallback if cmux didn't respond or parsing failed
[ -z "$CURRENT_WS" ] && CURRENT_WS=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")

cmux new-workspace \
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

## Self-closing spawned workspace

When the spawned workspace should live only as long as one task, the spawned
Claude needs to close its own workspace at the end. Two rules:

1. **Don't persist the workspace ref to a file inside `--cwd`.** The ref is
   already available inside the spawned shell:
   - `$CMUX_WORKSPACE_ID` — the UUID
   - `cmux identify --json | jq -r .caller.workspace_ref` — the short form
     (`workspace:N`)

   Both forms are accepted by `close-workspace`.

2. **Close last.** `cmux close-workspace --workspace "$CMUX_WORKSPACE_ID"`
   tears down the PTY, which kills Claude Code. Run it as the final
   subprocess call after every other cleanup step, and treat its failure as
   best-effort.

End-of-task hook for a spawned session:

```bash
cmux log --level success --source "<skill>" "done"
cmux clear-progress
cmux close-workspace --workspace "$CMUX_WORKSPACE_ID" || true
```
