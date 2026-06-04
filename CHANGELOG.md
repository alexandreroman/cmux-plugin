# Changelog

All notable changes to the cmux Claude Code plugin will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [1.5.1] — 2026-06-04

### Fixed
- Workspace grouping now follows cmux's documented group model, so each group shows a proper collapsible `📁 <repo-basename>` header again. `new-workspace` keeps the dedicated placeholder workspace that `cmux workspace-group create` spawns as the group's anchor — the anchor *is* the header — and folds the **origin** and each spawned slice in as members beneath it, reordering the origin first so the parent leads its slices. Previously it reassigned the anchor to the origin via `cmux workspace-group set-anchor` and closed the placeholder; because cmux draws the header from the original anchor and never promotes an existing workspace to anchor, that stripped the header and left the members rendered as a flat, header-less list.
- `close-workspace` and `cancel-workspace` dissolve the group by closing its placeholder anchor (cmux dissolves the group and preserves the origin as an ungrouped workspace), guarded so a group whose anchor is the origin itself is only `ungroup`ped — the origin is never closed. The "last slice" threshold accounts for the placeholder header now counting as a member.

### Added
- `references/workspace-lifecycle.md`: link to cmux's upstream `docs/workspace-groups.md`, documenting that a group's anchor is always a freshly-spawned dedicated workspace and is never promoted from an existing one.

---

## [1.5.0] — 2026-06-03

### Added
- Workspace grouping for isolated workspaces. `new-workspace` attaches each isolated workspace to a single sidebar group anchored on the **origin** workspace it was spawned from (the group header *is* the origin's sidebar row); repeated spawns from the same origin fold into that same group, so the sidebar shows one collapsible header per origin instead of a flat list. `close-workspace` and `cancel-workspace` dissolve the group (`cmux workspace-group ungroup`, which preserves the origin — never `delete`, which would close every member) once the closing workspace is the group's last slice; otherwise they just drop themselves from it. Grouping is best-effort — if any `cmux workspace-group` call fails, the worktree and workspace are still created and usable.
- `references/workspace-lifecycle.md`: document the one-group-per-origin model and when the group is dissolved.

### Changed
- Migrated the plugin's slash commands to skills, the format Claude Code commands have been merged into. Each `commands/<name>.md` moved to `skills/<name>/SKILL.md` with a `name:` (and, where relevant, `argument-hint:`) frontmatter field; `commands/` is removed. Invocation is unchanged — `/cmux:status`, `/cmux:open-browser`, `/cmux:new-workspace`, `/cmux:close-workspace`, and `/cmux:cancel-workspace` still work as slash commands, and Claude can now also auto-invoke each from its description. `$ARGUMENTS` substitution carries over unchanged.
- Reframed the documentation (`README.md`, `CLAUDE.md`, the `cmux` skill, and its references) to describe these as skills rather than slash commands.

---

## [1.4.2] — 2026-06-02

### Added
- `SKILL.md`: expand the `cmux diff` example with the agent-friendly `--last-turn` source (changes since this surface's last agent-turn baseline) and `--staged`, plus the `--layout split|unified` and `--font-size` presentation options.

---

## [1.4.1] — 2026-06-01

### Added
- `references/spawning-workspaces.md`: new "Grouping related spawns" section covering the `cmux workspace-group` namespace — anchor-owned collapsible sidebar groups, `create --from`, `add`, and `ungroup` vs the destructive `delete` (which closes every member).
- `SKILL.md`: document `cmux diff` for rendering a unified diff in a browser split (`--branch`, `--unstaged`, or piped stdin) as an artifact-display alternative to dumping a patch in the terminal.
- `CLAUDE.md`: present-tense documentation rule — skill and command docs describe the CLI as it currently is, with no "now"/"used to"/"previously" wording and no cmux version numbers in behavior descriptions.

### Changed
- Adopted the canonical `cmux workspace <list|create|close|rename>` noun namespace throughout the plugin — the skill, the slash commands (`commands/`), and the SessionStart hook (`scripts/cmux-session-start.sh`) — in place of the legacy `list-workspaces`/`new-workspace`/`close-workspace`/`rename-workspace` verbs (which still work but print a deprecation hint).
- `references/spawning-workspaces.md`: resolve the caller's workspace name via `cmux workspace list --json` + `jq` on `.title` instead of the brittle `sed`/`awk` column parse.
- `SKILL.md`: clarified `cmux open` routing — markdown opens in a markdown preview tab, other files in file preview tabs, URLs in a browser surface.

### Fixed
- `references/browser-automation.md`: restored the browser emulation and network subcommands (`viewport`, `geolocation`, `offline`, `network`, `trace`, `screencast`) to the "other useful subcommands" list (verified against cmux 0.64.11), and noted that `cmux browser open-split` defaults to `--focus false`.
- `scripts/cmux-session-start.sh` and `scripts/cmux-notify.sh`: corrected the default socket path in the in-cmux guard from `/tmp/cmux.sock` to `~/Library/Application Support/cmux/cmux.sock`, so the hooks no longer silently exit when `CMUX_SOCKET_PATH` is unset (matches the detection snippet already fixed in the skill).

---

## [1.4.0] — 2026-05-22

### Added
- `SKILL.md`: new section documenting `cmux open` — one-shot artifact display for paths and URLs (markdown viewer, browser surface, multiple inputs in one call), with targeting flags (`--workspace`, `--surface`, `--pane`, `--window`, `--focus|--no-focus`) and an explicit contrast with `cmux browser open-split` for scripted DOM work.

### Fixed
- `references/browser-automation.md`: removed `viewport`, `geolocation`, `offline`, `network` from the "other useful subcommands" list — these are not part of the current `cmux browser` CLI (verified against cmux 0.64.9). Replaced with `frame`, `highlight`, `state save|load`.

---

## [1.3.0] — 2026-05-14

### Changed (breaking)
- **Renamed the plugin from `cmux-plugin` to `cmux`.** The install command, skill name, and skill folder all use the shorter name; existing users must reinstall:
  - Install: `/plugin install cmux@cc-plugins` (was `cmux-plugin@cc-plugins`).
  - Skill ID inside the SessionStart hook context: `cmux:cmux` (was `cmux-plugin:cmux-plugin`). Update the JSON snippet in `~/.claude/settings.json` accordingly.
  - Skill folder on disk: `skills/cmux/` (was `skills/cmux-plugin/`).

  The GitHub repository URL is unchanged.
- **Renamed the feature-lifecycle slash commands and reframed them around isolated workspaces.** The behavior is unchanged (still creates/merges/discards a `feature/<slug>` worktree under `.worktrees/<slug>`), but the vocabulary now covers any isolated piece of work — a feature, a code review, a spike, a long refactor — instead of presuming "feature":
  - `/cmux:start-feature` → `/cmux:new-workspace`
  - `/cmux:finish-feature` → `/cmux:close-workspace`
  - `/cmux:abandon-feature` → `/cmux:cancel-workspace`

  Command files, descriptions, `references/feature-lifecycle.md` (→ `workspace-lifecycle.md`), the SKILL.md trigger section, and the README are rewritten with the broader framing. The `CMUX_FEATURE_*` env vars exposed to `post-create.sh` / `pre-destroy.sh` keep their names so existing project hook scripts continue to work. The `feature/<slug>` branch prefix is retained as a short-lived-branch convention regardless of what kind of work the workspace hosts.

---

## [1.2.4] — 2026-05-14

### Fixed
- `skills/cmux-plugin/SKILL.md`: detection snippet had the wrong default socket path. cmux 0.64.x stores its socket at `~/Library/Application Support/cmux/cmux.sock`, not `/tmp/cmux.sock`, so the `[ -S ... ]` check failed on machines where `CMUX_SOCKET_PATH` was unset — causing the skill to silently disable itself.
- Browser split example used a `--direction` flag on `cmux browser open-split` that the CLI silently ignores (and which never appeared in `cmux browser --help`). Replaced with the supported `cmux new-pane --type browser --direction <dir> --url <url>` pattern when direction matters, plus an example showing how to capture the surface ref returned by `open-split`.

### Changed
- Restructured `skills/cmux-plugin/` to follow the [agentskills.io](https://agentskills.io/specification) progressive-disclosure pattern. `SKILL.md` shrinks from 271 → 149 lines by moving detailed sections into `references/`:
  - `references/spawning-workspaces.md` — caller-prefix naming, `--cwd` semantics, self-closing spawned-workspace pattern.
  - `references/browser-automation.md` — full browser command examples and cleanup.
  - `references/feature-lifecycle.md` — trigger phrasing and preconditions for `/cmux:start-feature` / `finish-feature` / `abandon-feature`.
  - `references/superpowers-integration.md` — Superpowers↔cmux action mapping.

  Each reference is one level deep from `SKILL.md` and loaded on demand. The skill body stays focused on detection, triggers, and the rules — the procedural detail loads only when needed.
- Replaced the bloated "Full CLI Reference" section with a short "Discoverability" pointer (`cmux --help`, `cmux <cmd> --help`, `cmux docs <topic>`, `cmux capabilities`). The full surface is one shell call away and was wasting context on every invocation.
- Browser example now demonstrates capturing the surface ref from `open-split` output and cleaning up with `cmux close-surface` instead of just saying "close when done".

---

## [1.2.3] — 2026-05-11

### Fixed
- `cmux-session-start.sh`: the 1.2.2 "skip rename when a custom name is set" guard never fired. It awked `cmux list-workspaces` for a row matching `$CMUX_WORKSPACE_ID`, but that env var is a UUID while the listing only emits short refs (`workspace:N`) in column 1 — so the lookup always returned empty and the hook still renamed every workspace on session start. Now resolves UUID → ref via `cmux identify --workspace <id>` before the lookup. Custom names set via `cmux new-workspace --name` are preserved as intended.

---

## [1.2.2] — 2026-05-11

### Fixed
- `cmux-session-start.sh` no longer clobbers workspace names set via `cmux new-workspace --name`. The hook used to unconditionally rename the workspace to the repo basename on every session start, overwriting names chosen by callers (e.g. `/process-url` spawning `<parent>-process-url-<id>`). It now skips the rename when the workspace already has a non-default name.

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
