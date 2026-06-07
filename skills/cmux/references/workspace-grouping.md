# Workspace grouping — optional sidebar folder for the lifecycle skills

`/cmux:new-workspace`, `/cmux:close-workspace`, and `/cmux:cancel-workspace` can
optionally gather an **origin** workspace and the isolated slices spawned from it
under one collapsible `📁 <repo-basename>` sidebar folder.

Grouping is **opt-in**: only do it when the user explicitly asks. Spawning or
closing a workspace is not by itself a request to group it.

## cmux's group model

A group is owned by an **anchor** — a dedicated, freshly-spawned workspace that
*is* the `📁` header row (there is no separate row for it). cmux never promotes
an existing workspace to anchor; the anchor is always the placeholder that `cmux
workspace-group create` spawns. So **keep that placeholder** — reassigning the
anchor to a real workspace or closing the placeholder strips the header and the
members collapse into a flat, header-less list. See
[cmux's workspace-groups doc](https://github.com/manaflow-ai/cmux/blob/main/docs/workspace-groups.md).

The folder holds the origin plus each spawned slice as members; there is exactly
one folder per origin.

## Create or join — for `/cmux:new-workspace`

Input: `$NEW_WS`, the ref of the workspace just created. Best-effort: if any call
fails, log it and carry on — the workspace is already usable ungrouped.

```bash
ORIGIN=$(cmux identify --json | jq -r '.caller.workspace_ref')
# Reuse the origin's group if it has one; otherwise create it. `create --from`
# spawns the placeholder anchor (the `📁 <repo-basename>` header) and folds the
# origin in as a member.
GROUP=$(cmux workspace-group list --json \
  | jq -r --arg o "$ORIGIN" '.groups[] | select(.member_workspace_refs | index($o)) | .ref' \
  | head -n1)
if [ -z "$GROUP" ]; then
  GROUP=$(cmux workspace-group create --name "<repo-basename>" --from "$ORIGIN" | awk '{print $2}')
fi
# Add the new slice, then keep the origin first under the header (`add` drops the
# new member right after the anchor, ahead of the origin).
cmux workspace-group add --group "$GROUP" --workspace "$NEW_WS"
ANCHOR=$(cmux workspace-group list --json \
  | jq -r --arg g "$GROUP" '.groups[] | select(.ref==$g) | .anchor_workspace_ref')
cmux reorder-workspace --workspace "$ORIGIN" --after "$ANCHOR"
```

## Dissolve — for `/cmux:close-workspace` and `/cmux:cancel-workspace`

Run this *before* closing the current workspace (once it closes, this Claude is
gone and can't clean up). Best-effort. Input: `<main-worktree>`, the main
worktree path the skill already resolved. If the workspace isn't grouped, the
block finds no group and is a harmless no-op.

```bash
SELF=$(cmux identify --json | jq -r '.caller.workspace_ref')
GROUP=$(cmux workspace-group list --json \
  | jq -r --arg s "$SELF" '.groups[] | select(.member_workspace_refs | index($s)) | .ref' \
  | head -n1)
if [ -n "$GROUP" ]; then
  COUNT=$(cmux workspace-group list --json \
    | jq -r --arg g "$GROUP" '.groups[] | select(.ref==$g) | .member_count')
  if [ "$COUNT" -le 3 ]; then
    # Only the placeholder header + origin + us remain. Dissolve by closing the
    # anchor (the placeholder); cmux dissolves the group and preserves the origin
    # as an ungrouped workspace. The placeholder shares the origin's directory,
    # so identify the origin as a *distinct* member at the main worktree, and
    # only close the anchor when such a member exists — that proves the anchor is
    # the throwaway placeholder, not the origin itself.
    ANCHOR=$(cmux workspace-group list --json \
      | jq -r --arg g "$GROUP" '.groups[] | select(.ref==$g) | .anchor_workspace_ref')
    ORIGIN=$(cmux workspace list --json \
      | jq -r --arg d "<main-worktree>" --arg a "$ANCHOR" \
          '.workspaces[]? | select(.current_directory==$d and .ref!=$a) | .ref' \
      | head -n1)
    if [ -n "$ANCHOR" ] && [ "$ANCHOR" != "$SELF" ] && [ -n "$ORIGIN" ]; then
      cmux workspace close "$ANCHOR"
    else
      cmux workspace-group ungroup "$GROUP"
    fi
  else
    # Other slices remain — just drop ourselves from the group.
    cmux workspace-group remove --workspace "$SELF"
  fi
fi
```
