---
description: Start a new feature in an isolated cmux workspace. Creates a `feature/<slug>` git worktree under `.worktrees/<slug>`, opens it in a new cmux workspace, and launches Claude Code there. Argument: feature name (required, e.g. `auth-jwt`).
---

Start a new feature in an isolated cmux workspace.

The user provided this feature name (raw, may need sanitizing): `$ARGUMENTS`

Follow these steps strictly. If any check fails, stop and report the reason.

1. **Verify cmux is available.** Run the detection block from the cmux-plugin skill (`CMUX_WORKSPACE_ID`, socket, `cmux` binary). If not inside cmux, explain that this command requires cmux and stop.

2. **Validate the argument.** If `$ARGUMENTS` is empty or only whitespace, ask the user for a feature name and stop.

3. **Sanitize into a slug.** Lowercase; replace spaces and underscores with `-`; collapse consecutive dashes; strip anything that is not `[a-z0-9-]`. Reject if the slug is empty after sanitizing. Use this slug for the rest of the command.

4. **Confirm we are in the main worktree of a git repo.**
   - `git rev-parse --show-toplevel` → `<repo-root>` (must succeed).
   - `git rev-parse --git-common-dir` and `git rev-parse --git-dir` — if they differ, we are inside a linked worktree. Refuse: tell the user to run this from the main repo, not from another feature worktree.

5. **Resolve the base branch** (the branch the new feature branches from):
   - Try `git symbolic-ref --short refs/remotes/origin/HEAD` and strip the `origin/` prefix.
   - Fallback: `main` if it exists locally, else `master` if it exists.
   - Last resort: the current `HEAD` branch name in the main worktree.

6. **Compute paths and names.**
   - Branch: `feature/<slug>`
   - Worktree path: `<repo-root>/.worktrees/<slug>`
   - Workspace tab name: `<slug>` (cmux's `SessionStart` hook will rewrite it to `<repo>:<branch>` once Claude starts)

7. **Pre-flight checks.** All must pass:
   - The branch must not already exist: `git show-ref --verify --quiet refs/heads/feature/<slug>` should fail (exit non-zero).
   - The worktree path must not exist on disk.
   - `git worktree list --porcelain` must not already reference the path.

8. **Ensure `.worktrees/` is gitignored.** Read `<repo-root>/.gitignore` (create if missing). If it does not contain a line matching `.worktrees` or `.worktrees/`, append `.worktrees/` on a new line. Stage and commit only if the user explicitly asks — by default, just edit the file and let them decide.

9. **Create the worktree.**
   ```bash
   git worktree add -b feature/<slug> <repo-root>/.worktrees/<slug> <base-branch>
   ```

10. **Open a new cmux workspace and launch Claude Code in it.**
    ```bash
    cmux new-workspace \
      --name "<slug>" \
      --cwd "<repo-root>/.worktrees/<slug>" \
      --command "claude" \
      --focus true
    ```

11. **Log a sidebar entry in the *current* workspace** (the main one — we are still here):
    ```bash
    cmux log --level success --source "claude" -- "Started feature/<slug> → .worktrees/<slug>"
    ```

12. **Report to the user.** One short paragraph: branch name, worktree path, that the new cmux workspace is focused with Claude Code starting up. Suggest `/cmux:finish-feature` (merge + cleanup) or `/cmux:abandon-feature` (cleanup without merge) when done.
