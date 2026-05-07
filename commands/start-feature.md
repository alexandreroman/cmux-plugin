---
description: PROACTIVE — invoke whenever the user is about to start work on a new feature, even without typing the slash command. Triggers on phrases like "new feature", "let's add X", "build a Y", "implement Z", "I want to create", "let's work on", "start a branch for", or any substantive new piece of work that deserves an isolated branch. When the user describes such work from the main worktree of a cmux-enabled repo, suggest this command (or run it directly in auto mode) before touching code, so the work happens in its own worktree and cmux workspace. Skip for quick one-off fixes, doc tweaks, or when already inside a feature worktree. Creates a `feature/<slug>` git worktree under `.worktrees/<slug>`, opens it in a new cmux workspace, and launches Claude Code there. Argument: feature name (required, e.g. `auth-jwt`).
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
   - Workspace tab name: `<repo-basename>-<slug>` (e.g. from `durable-money`, feature `2pc` → `durable-money-2pc`). `<repo-basename>` is the basename of `<repo-root>`. cmux's `SessionStart` hook produces the same format on every Claude start, so the tab name stays stable.

7. **Pre-flight checks.** All must pass:
   - The branch must not already exist: `git show-ref --verify --quiet refs/heads/feature/<slug>` should fail (exit non-zero).
   - The worktree path must not exist on disk.
   - `git worktree list --porcelain` must not already reference the path.

8. **Ensure `.worktrees/` is gitignored.** Read `<repo-root>/.gitignore` (create if missing). If it does not contain a line matching `.worktrees` or `.worktrees/`, append `.worktrees/` on a new line. Stage and commit only if the user explicitly asks — by default, just edit the file and let them decide.

9. **Create the worktree.**
   ```bash
   git worktree add -b feature/<slug> <repo-root>/.worktrees/<slug> <base-branch>
   ```

10. **Symlink dev-time secret/config files from the main worktree** so the feature
    worktree shares them. For each filename in this list, if it exists in
    `<repo-root>/` and does *not* already exist in `<worktree>/`, create a relative
    symlink in the worktree pointing back to the main worktree's file:
    - `.env`
    - `.env.local`
    - `.env.development`
    - `.env.development.local`
    - `.envrc`

    Use a relative target so the link survives if the parent dir is renamed:
    ```bash
    ln -s ../../.env <repo-root>/.worktrees/<slug>/.env
    ```
    Skip silently if the source does not exist. Collect the list of linked files
    to mention in the final report. Never overwrite an existing file in the
    worktree.

11. **Run the optional setup hook in the new workspace.** If
    `<repo-root>/.cmux/setup-worktree.sh` exists and is executable in the new
    worktree (it is, if it is committed and executable in the repo), chain it
    before `claude` in the workspace's startup command. The hook runs with the
    feature worktree as cwd and these env vars exported:
    - `CMUX_FEATURE_SLUG=<slug>`
    - `CMUX_FEATURE_BRANCH=feature/<slug>`
    - `CMUX_FEATURE_WORKTREE=<repo-root>/.worktrees/<slug>`
    - `CMUX_MAIN_WORKTREE=<repo-root>`

    Do not auto-detect package managers or run `uv sync` / `npm install` /
    similar yourself. The hook is the project's responsibility — if it is not
    present, just launch `claude`.

12. **Open a new cmux workspace and launch Claude Code in it.** Build the
    `--command` so the setup hook (if any) runs first, then Claude Code starts.
    Even if the hook fails, the user lands in the worktree's terminal.
    ```bash
    # If <repo-root>/.cmux/setup-worktree.sh exists in the new worktree:
    SETUP_AND_CLAUDE='CMUX_FEATURE_SLUG=<slug> CMUX_FEATURE_BRANCH=feature/<slug> '\
'CMUX_FEATURE_WORKTREE=<wt> CMUX_MAIN_WORKTREE=<repo-root> '\
'./.cmux/setup-worktree.sh && claude'
    # Otherwise:
    SETUP_AND_CLAUDE='claude'

    cmux new-workspace \
      --name "<repo-basename>-<slug>" \
      --cwd "<repo-root>/.worktrees/<slug>" \
      --command "$SETUP_AND_CLAUDE" \
      --focus true
    ```

13. **Log a sidebar entry in the *current* workspace** (the main one — we are
    still here):
    ```bash
    cmux log --level success --source "claude" -- "Started feature/<slug> → .worktrees/<slug>"
    ```

14. **Report to the user.** One short paragraph including:
    - Branch and worktree path
    - Which env files were symlinked (or "none")
    - Whether the setup hook was found and chained, or skipped
    - That the new cmux workspace is focused with Claude Code starting up
    - Suggestion: `/cmux:finish-feature` or `/cmux:abandon-feature` when done
