---
description: PROACTIVE — invoke when the user wants to throw away the current feature: "abandon", "discard this", "scrap it", "let's start over", "this isn't working", "forget this branch", "nuke this worktree". Only meaningful from inside a feature worktree (linked worktree, typically on a `feature/*` branch). Suggest or run this instead of manually deleting branches/worktrees. Destructive: removes the worktree, force-deletes the feature branch, and closes the cmux workspace; any uncommitted or unmerged commits are lost. Requires explicit confirmation via AskUserQuestion before destroying anything, even in auto mode.
---

Abandon the current feature: discard all changes and clean up.

This command is destructive — uncommitted work and unmerged commits will be lost. You MUST get explicit user confirmation before running steps 7+.

1. **Verify cmux is available** (same detection as in the cmux-plugin skill). If not inside cmux, stop.

2. **Confirm we are inside a linked worktree** (not the main repo): `git rev-parse --git-common-dir` and `git rev-parse --git-dir` must differ. If we are in the main worktree, refuse.

3. **Identify the feature branch and main worktree** (same as `finish-feature`):
   - Feature branch: `git rev-parse --abbrev-ref HEAD`.
   - Feature worktree path: `git rev-parse --show-toplevel`.
   - Main worktree path: from `git worktree list --porcelain` (or dirname of `git rev-parse --git-common-dir` without `/.git`).

4. **Resolve the base branch** (same logic as `start-feature`).

5. **Show the user exactly what will be lost:**
   - Uncommitted changes: `git status --short` (echo as a fenced block).
   - Unmerged commits: `git log --oneline <base-branch>..HEAD` (echo as a fenced block).
   - Current worktree path.

6. **Ask for explicit confirmation.** Use `AskUserQuestion` with two options: `Abandon and delete` and `Cancel`. Default to `Cancel`. Stop unless the user picks `Abandon and delete`.

   In auto mode, you must still show the diff/commit list and use `AskUserQuestion` — destructive operations require explicit confirmation regardless of auto mode.

7. **Capture the cmux workspace ID** from `cmux identify --json`.

8. **Force-remove the worktree** from the main repo (we are still in the worktree's cwd; that is fine because `git worktree remove` is run with `git -C <main>` and `--force`):
   ```bash
   git -C <main-worktree> worktree remove --force <feature-worktree-path>
   ```

9. **Force-delete the local branch** (it is unmerged, so `-D` is required):
   ```bash
   git -C <main-worktree> branch -D feature/<slug>
   ```

10. **Close this cmux workspace** (last — this kills the running Claude Code):
    ```bash
    cmux close-workspace --workspace $CMUX_WORKSPACE_ID
    ```

Do not touch `origin` — never push or delete remote branches from this command.
