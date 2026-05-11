---
description: PROACTIVE — invoke when work inside a feature worktree is complete and the user signals they want to ship it: "merge it", "ship it", "this is done", "wrap this up", "let's land this", or after tests/checks pass and they want to integrate. Only meaningful from inside a feature worktree created by `/cmux:start-feature` (linked worktree, on a `feature/*` branch). Suggest or run this instead of doing the merge by hand. Merges the feature branch into the base branch with plain `git merge` (fast-forward when possible), removes the worktree and local branch, and closes the cmux workspace.
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

6. **Capture this workspace's ref.** Inside cmux, `$CMUX_WORKSPACE_ID` is already set to the UUID; if you need the short form (`workspace:N`), use `cmux identify --json | jq -r .caller.workspace_ref`. Either form is accepted by `close-workspace`. We will close it last (step 13).

7. **Confirm the main worktree is on the base branch.**
   - `git -C <main-worktree> rev-parse --abbrev-ref HEAD` must equal the base branch.
   - If not, refuse: tell the user to switch the main worktree to `<base-branch>` first. Do not silently switch it.

8. **Merge the feature branch into the base branch** (from the main worktree, default fast-forward behavior):
   ```bash
   git -C <main-worktree> merge feature/<slug>
   ```
   - If the merge fails (conflicts), abort it: `git -C <main-worktree> merge --abort`. Report and stop. The user must resolve manually.

9. **Run the optional `pre-destroy` hook.** If
   `<feature-worktree-path>/.cmux/pre-destroy.sh` exists and is executable, run
   it from the feature worktree (cwd = `<feature-worktree-path>`) with the same
   env vars `/cmux:start-feature` exports:
   - `CMUX_FEATURE_SLUG=<slug>`
   - `CMUX_FEATURE_BRANCH=feature/<slug>`
   - `CMUX_FEATURE_WORKTREE=<feature-worktree-path>`
   - `CMUX_MAIN_WORKTREE=<main-worktree>`

   The hook is the project's chance to tear down side-effect state created by
   `post-create.sh` (stop a dev server, drop a temp database, prune containers,
   etc.). If the hook exits non-zero, stop and report the failure — do not
   remove the worktree. The merge has already landed, so re-running the command
   after the user fixes the hook will be a no-op for the merge step and will
   continue to the cleanup. Skip silently if the hook is absent.

10. **Remove the worktree.** Run from the main worktree so we are not removing our own cwd:
    ```bash
    git -C <main-worktree> worktree remove <feature-worktree-path>
    ```

11. **Delete the local feature branch** (safe delete — it is now merged):
    ```bash
    git -C <main-worktree> branch -d feature/<slug>
    ```

12. **Notify the *main* workspace's sidebar** (find it via `cmux list-workspaces` if you can match by name; otherwise skip — the closing workspace's log will be discarded with it):
    ```bash
    cmux log --level success --source "claude" --workspace <main-workspace-id> \
      -- "Merged feature/<slug> → <base-branch>; worktree removed"
    ```
    If you cannot reliably identify the main workspace, skip this step rather than guessing.

13. **Close this cmux workspace.** This terminates the running Claude Code; do it last.
    ```bash
    cmux close-workspace --workspace $CMUX_WORKSPACE_ID
    ```

Do not push to `origin` unless the user explicitly asks. Do not delete the remote branch.
