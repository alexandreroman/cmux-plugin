---
name: cancel-workspace
description: PROACTIVE — destructively discard an isolated cmux workspace: force-remove the worktree, force-delete the branch, and close the cmux workspace. Any uncommitted or unmerged work is lost. Triggers on "abandon", "discard this", "scrap it", "let's start over", "this isn't working", "forget this branch", "nuke this workspace". Run from inside an isolated worktree; suggest or run this instead of manually deleting branches/worktrees. Always asks for explicit confirmation via AskUserQuestion, even in auto mode.
---

Cancel the current isolated workspace: discard all changes and clean up.

This skill is destructive — uncommitted work and unmerged commits will be lost. You MUST get explicit user confirmation before running steps 7+.

1. **Verify cmux is available** (same detection as in the cmux skill). If not inside cmux, stop.

2. **Confirm we are inside a linked worktree** (not the main repo): `git rev-parse --git-common-dir` and `git rev-parse --git-dir` must differ. If we are in the main worktree, refuse.

3. **Identify the workspace branch and main worktree** (same as `close-workspace`):
   - Branch: `git rev-parse --abbrev-ref HEAD`.
   - Isolated worktree path: `git rev-parse --show-toplevel`.
   - Main worktree path: from `git worktree list --porcelain` (or dirname of `git rev-parse --git-common-dir` without `/.git`).

4. **Resolve the base branch** (same logic as `new-workspace`).

5. **Show the user exactly what will be lost:**
   - Uncommitted changes: `git status --short` (echo as a fenced block).
   - Unmerged commits: `git log --oneline <base-branch>..HEAD` (echo as a fenced block).
   - Current worktree path.

6. **Ask for explicit confirmation.** Use `AskUserQuestion` with two options: `Abandon and delete` and `Cancel`. Default to `Cancel`. Stop unless the user picks `Abandon and delete`.

   In auto mode, you must still show the diff/commit list and use `AskUserQuestion` — destructive operations require explicit confirmation regardless of auto mode.

7. **Capture the cmux workspace ID** from `cmux identify --json`.

8. **Run the optional `pre-destroy` hook.** If
   `<worktree-path>/.cmux/pre-destroy.sh` exists and is executable, run
   it from the worktree (cwd = `<worktree-path>`) with the same env vars
   `/cmux:new-workspace` exports (names kept stable for backwards compatibility
   with existing project hook scripts):
   - `CMUX_FEATURE_SLUG=<slug>`
   - `CMUX_FEATURE_BRANCH=feature/<slug>`
   - `CMUX_FEATURE_WORKTREE=<worktree-path>`
   - `CMUX_MAIN_WORKTREE=<main-worktree>`

   The hook is the project's chance to tear down side-effect state created by
   `post-create.sh` (stop a dev server, drop a temp database, prune containers,
   etc.). If the hook exits non-zero, stop and report the failure — do not
   remove the worktree. The user must fix the hook (or delete it) and re-run.
   Skip silently if the hook is absent.

9. **Force-remove the worktree** from the main repo (we are still in the worktree's cwd; that is fine because `git worktree remove` is run with `git -C <main>` and `--force`):
   ```bash
   git -C <main-worktree> worktree remove --force <worktree-path>
   ```

10. **Force-delete the local branch** (it is unmerged, so `-D` is required):
    ```bash
    git -C <main-worktree> branch -D feature/<slug>
    ```

11. **Dissolve the origin's group if this is its last slice.** This workspace
    belongs to the origin's sidebar group (created by `/cmux:new-workspace`).
    Once it leaves, the group may hold only the origin — a one-member group is
    pointless, so dissolve it. Do this *before* closing our own workspace (next
    step): once the workspace closes, this Claude is gone and cannot run the
    cleanup. Treat the whole step as best-effort.
    ```bash
    SELF=$(cmux identify --json | jq -r '.caller.workspace_ref')
    GROUP=$(cmux workspace-group list --json \
      | jq -r --arg s "$SELF" \
          '.groups[] | select(.member_workspace_refs | index($s)) | .ref' \
      | head -n1)
    if [ -n "$GROUP" ]; then
      COUNT=$(cmux workspace-group list --json \
        | jq -r --arg g "$GROUP" '.groups[] | select(.ref==$g) | .member_count')
      if [ "$COUNT" -le 2 ]; then
        # us plus at most the origin → dissolving leaves the origin ungrouped.
        # Never use `delete`: that would close the origin too.
        cmux workspace-group ungroup "$GROUP"
      else
        # other slices remain — just drop ourselves from the group.
        cmux workspace-group remove --workspace "$SELF"
      fi
    fi
    ```

12. **Close this cmux workspace** (last — this kills the running Claude Code):
    ```bash
    cmux workspace close $CMUX_WORKSPACE_ID
    ```

Do not touch `origin` — never push or delete remote branches from this skill.
