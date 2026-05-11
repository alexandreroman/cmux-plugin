# Changelog

All notable changes to the cmux Claude Code plugin will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [1.2.1] — 2026-05-11

### Changed
- Documented `new-workspace --cwd <path>` semantics in `SKILL.md` and the robust pattern for self-closing spawned workspaces (read `$CMUX_WORKSPACE_ID` or `cmux identify --json | jq .caller.workspace_ref`, then close as a final best-effort step).
- Fixed `commands/finish-feature.md` step 6: `cmux identify --json` exposes the workspace ref at `.caller.workspace_ref`, not `.workspace_id` / `.workspace`.
- README now lists the `Notification` hook in the features table and corrects the `cmux-notify.sh` description to cover all forwarded events (not just sub-agent notifications).

---

## [1.2.0] — 2026-05-07

### Added
- `pre-destroy` hook: `/cmux:finish-feature` and `/cmux:abandon-feature` now run an optional `<repo>/.cmux/pre-destroy.sh` from the feature worktree before removing it, with the same `CMUX_FEATURE_*` env vars `start-feature` exports. Symmetric counterpart to `post-create.sh` for tearing down state created at setup (stopping a dev server, dropping a temp DB, pruning containers). If the hook exits non-zero the worktree is left intact so the user can fix and retry.

### Changed
- Renamed the worktree setup hook from `<repo>/.cmux/setup-worktree.sh` to `<repo>/.cmux/post-create.sh`. Naming aligns with the devcontainer `postCreateCommand` idiom and pairs cleanly with the new `pre-destroy.sh` lifecycle hook. **Breaking**: existing repos must rename the file.

---

## [1.1.3] — 2026-05-07

### Changed
- Rewrote the descriptions of `/cmux:start-feature`, `/cmux:finish-feature`, and `/cmux:abandon-feature` so Claude recognizes when to invoke them from natural phrasing — "new feature", "let's add X", "ship it", "merge it", "abandon", "scrap this" — rather than only when the slash command is typed verbatim. Also added a "Feature lifecycle — start / finish / abandon" section and a matching rule in the cmux-plugin skill, so the guidance is loaded automatically whenever Claude runs inside cmux.

---

## [1.1.2] — 2026-05-06

### Changed
- `SKILL.md` now prescribes a workspace naming convention for *every* new workspace Claude opens (not just `/cmux:start-feature` worktrees): `<current-workspace-name>-<task-slug>`, set via `--name` at creation time. Example: from `durable-money`, opening a code review → `durable-money-code-review`. Previously Claude would sometimes use a bare task slug, losing the parent context in the sidebar.

---

## [1.1.1] — 2026-05-06

### Fixed
- Workspace tab name in linked worktrees is now `<main-repo-basename>-<branch-leaf>` (e.g. `durable-money-2pc`) instead of `<linked-worktree-basename>:<full-branch>` (e.g. `2pc:feature/2pc`). Two underlying fixes: (1) `cmux-session-start.sh` now resolves the project name from the *main* worktree (via `git rev-parse --git-common-dir`) instead of the linked worktree's directory; (2) the separator changed from `:` to `-` and only the branch leaf is used (e.g. `feature/2pc` → `2pc`). `/cmux:start-feature` sets the same format up-front so the name stays stable across Claude restarts.

---

## [1.1.0] — 2026-05-06

### Added
- `/cmux:start-feature <name>` — creates a `feature/<slug>` git worktree under `<repo>/.worktrees/<slug>`, opens a new cmux workspace focused on it, and launches a Claude Code instance there. Adds `.worktrees/` to the repo's `.gitignore` if missing.
- `/cmux:finish-feature` — run from inside a feature worktree: merges the feature branch into the base branch (plain `git merge`, fast-forward when possible), removes the worktree, deletes the local branch, and closes the cmux workspace. Refuses on dirty trees, merge conflicts, or wrong base branch.
- `/cmux:abandon-feature` — destructive variant: shows the unmerged commits and uncommitted changes, asks for explicit confirmation, then force-removes the worktree, force-deletes the branch, and closes the cmux workspace.
- Worktree setup in `/cmux:start-feature`: relative-symlinks dev-time secret/config files from the main worktree (`.env`, `.env.local`, `.env.development`, `.env.development.local`, `.envrc`) when present, and runs an optional `<repo>/.cmux/setup-worktree.sh` hook in the new workspace before launching Claude Code. The hook receives `CMUX_FEATURE_SLUG`, `CMUX_FEATURE_BRANCH`, `CMUX_FEATURE_WORKTREE`, `CMUX_MAIN_WORKTREE` as env vars and decides what "setup" means (uv sync, pnpm install, etc.). No package-manager auto-detection.

### Changed
- `cmux-session-start.sh` now appends the branch to the workspace tab name when running inside a linked git worktree (e.g. `cmux-plugin:feature/auth-jwt`), so parallel feature workspaces are visually distinct in the sidebar. Behavior in the main worktree is unchanged.
- `cmux-notify.sh` now forwards every `Notification` event to cmux uniformly, with no per-message filtering.

---

## [1.0.4] — 2026-05-05

### Added
- `Notification` hook (`cmux-notify.sh`) that forwards Claude Code notification events (permission prompts, idle events, etc.) to cmux as native notifications, replacing Claude Code's default OS notifications

---

## [1.0.3] — 2026-05-05

### Fixed
- Removed the `Stop` hook to avoid duplicate end-of-turn notifications. cmux already shows a native notification with the response content when Claude finishes; the plugin's static "Session complete" notification was redundant. Sub-agent notifications via `PostToolUse(Task)` are kept

### Changed
- Sub-agent notifications now include the agent type (`subagent_type`) and short description (`description`) extracted from the `Task` tool input, e.g. `Explore: Branch ship-readiness audit`

---

## [1.0.2] — 2026-05-04

### Fixed
- Flattened plugin layout: moved `.claude-plugin/`, `commands/`, `hooks/`, `scripts/`, `skills/` from the `cmux-plugin/` subdirectory to the repo root so Claude Code detects the skill correctly

---

## [1.0.1] — 2026-03-12

### Fixed
- `plugin.json`: `author` must be an object, not a string; removed unsupported `requirements` key
- Restructured repo as a proper marketplace with the plugin in a `cmux/` subdirectory
- `hooks.json`: hook entries must be objects with `type`/`command` fields, not bare strings; use `${CLAUDE_PLUGIN_ROOT}` for portable paths
- `SKILL.md`: aligned CLI reference with actual cmux commands (`list-logs` → `list-log`, `flash-pane` → `trigger-flash`, `switch-workspace` → `select-workspace`, corrected flag syntax)
- `commands/status.md`: corrected `list-logs` → `list-log`
- `cmux-session-start.sh`: fixed `rename-workspace` to use `--workspace` flag (was silently failing)

### Added
- `marketplace.json` for plugin registry support
- Sidebar status metadata commands in SKILL.md (`set-status`, `clear-status`, `list-status`, `sidebar-state`)

---

## [1.0.0] — 2026-03-12

### Added
- `SessionStart` hook: auto-renames cmux workspace tab to git repo name + branch
- `Stop` hook: cmux notification when Claude session completes
- `PostToolUse(Task)` hook: cmux notification when sub-agent finishes
- `skills/cmux/SKILL.md`: teaches Claude when and how to use all cmux features
- Superpowers plugin integration guidance in skill (worktrees → new workspace, subagent-driven-development → progress bar, finishing-a-development-branch → notification)
- `/cmux:status` slash command — orientation view of current workspace state
- `/cmux:open-browser` slash command — open browser split for dev server verification
- Silent no-op behavior when not running inside cmux (guards on `CMUX_WORKSPACE_ID` and socket path)
