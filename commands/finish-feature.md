---
description: Finish the current feature: merge the feature branch into the base branch, remove the worktree and local branch, and close the cmux workspace. Run this from inside a feature worktree created by `/cmux:start-feature`. Uses plain `git merge` (fast-forward when possible).
---

Finish the current feature: merge into the base branch and clean up.

Follow these steps strictly. If any check fails, stop and report the reason — do not attempt to recover destructively.

1. **Verify cmux is available** (same detection as in the cmux-plugin skill). If not inside cmux, stop.

2. **Confirm we are inside a linked worktree** (not the main repo):
   - `git rev-parse --git-common-dir` and `git rev-parse --git-dir` must differ.
   - If we are in the main worktree, refuse and tell the user this command must be run from a feature worktree.

3. **Identify the feature branch and main worktree.**
   - Feature branch: `git rev-parse --abbrev-ref HEAD`. Reject if it is `HEAD` (detached) or empty.
   - Feature worktree path: `git rev-parse --show-toplevel`.
   - Main worktree path: parse `git worktree list --porcelain` — the first entry whose `worktree` line is not the current one and is not marked `bare`. Equivalently, dirname of `git rev-parse --git-common-dir` (without the trailing `/.git`).

4. **Verify the worktree is clean.**
   - `git status --porcelain` must be empty. If not, list the dirty paths and stop. Tell the user to commit, stash, or discard before retrying.

5. **Resolve the base branch** (same logic as `start-feature`): try `origin/HEAD`, then local `main`, then `master`. Reject if it equals the feature branch.

6. **Capture the cmux workspace ID** from `cmux identify --json` (jq `.workspace_id` or `.workspace`). We will close it last.

7. **Confirm the main worktree is on the base branch.**
   - `git -C <main-worktree> rev-parse --abbrev-ref HEAD` must equal the base branch.
   - If not, refuse: tell the user to switch the main worktree to `<base-branch>` first. Do not silently switch it.

8. **Merge the feature branch into the base branch** (from the main worktree, default fast-forward behavior):
   ```bash
   git -C <main-worktree> merge feature/<slug>
   ```
   - If the merge fails (conflicts), abort it: `git -C <main-worktree> merge --abort`. Report and stop. The user must resolve manually.

9. **Remove the worktree.** Run from the main worktree so we are not removing our own cwd:
   ```bash
   git -C <main-worktree> worktree remove <feature-worktree-path>
   ```

10. **Delete the local feature branch** (safe delete — it is now merged):
    ```bash
    git -C <main-worktree> branch -d feature/<slug>
    ```

11. **Notify the *main* workspace's sidebar** (find it via `cmux list-workspaces` if you can match by name; otherwise skip — the closing workspace's log will be discarded with it):
    ```bash
    cmux log --level success --source "claude" --workspace <main-workspace-id> \
      -- "Merged feature/<slug> → <base-branch>; worktree removed"
    ```
    If you cannot reliably identify the main workspace, skip this step rather than guessing.

12. **Close this cmux workspace.** This terminates the running Claude Code; do it last.
    ```bash
    cmux close-workspace --workspace $CMUX_WORKSPACE_ID
    ```

Do not push to `origin` unless the user explicitly asks. Do not delete the remote branch.
