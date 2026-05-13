# CMUX-PLUGIN — for Claude Code

Integrates [Claude Code](https://claude.ai/code) with [cmux](https://www.cmux.dev) — the native macOS terminal built for AI coding agents.

## What It Does

| Feature | How it works |
|---|---|
| **Auto workspace naming** | `SessionStart` hook renames the cmux sidebar tab to your git repo name + branch on every session |
| **Sub-agent notifications** | `PostToolUse(Task)` hook fires a cmux notification when a sub-agent finishes. End-of-turn notifications are handled natively by cmux, so the plugin does not duplicate them |
| **Notification forwarding** | `Notification` hook forwards Claude Code events (permission prompts, idle pings, etc.) to cmux as native notifications, replacing the default OS pop-ups |
| **Sidebar progress** | The cmux skill teaches Claude to report long-running task progress as a live progress bar in the sidebar |
| **Browser split automation** | Claude proactively opens a browser split when it needs to visually verify your dev server or debug UI |
| **Feature worktree workflow** | `/cmux:start-feature`, `/cmux:finish-feature`, `/cmux:abandon-feature` — git worktree + isolated cmux workspace per feature, with a Claude Code instance per worktree |
| **Superpowers integration** | When the [Superpowers plugin](https://claude.com/plugins/superpowers) triggers `using-git-worktrees`, Claude opens a new cmux workspace for the branch automatically |
| **Slash commands** | `/cmux:status`, `/cmux:open-browser`, `/cmux:start-feature`, `/cmux:finish-feature`, `/cmux:abandon-feature` |

## Requirements

- macOS 14.0+
- [cmux](https://www.cmux.dev) installed (`brew tap manaflow-ai/cmux && brew install --cask cmux`)
- cmux CLI symlinked: `sudo ln -sf "/Applications/cmux.app/Contents/Resources/bin/cmux" /usr/local/bin/cmux`
- `jq` installed (`brew install jq`)

## Installation

```bash
# In Claude Code
/plugin marketplace add alexandreroman/cc-plugins
/plugin install cmux@cc-plugins
/reload-plugins
```

## Slash Commands

| Command | Description |
|---|---|
| `/cmux:status` | Show current workspace, panes, surfaces, and sidebar log |
| `/cmux:open-browser [url]` | Open a browser split (defaults to `localhost:3000`) |
| `/cmux:start-feature <name>` | Create a `feature/<slug>` worktree under `.worktrees/<slug>`, open a new cmux workspace, and launch Claude Code in it |
| `/cmux:finish-feature` | Merge the feature branch into the base branch (fast-forward when possible), remove the worktree and local branch, close the cmux workspace. Run from the feature worktree |
| `/cmux:abandon-feature` | Discard the feature: force-remove the worktree, force-delete the branch, close the cmux workspace. Asks for confirmation. Run from the feature worktree |

### Feature workflow

```bash
# from the main repo workspace
/cmux:start-feature auth-jwt
#  → creates branch feature/auth-jwt
#  → creates worktree at <repo>/.worktrees/auth-jwt
#  → opens a new cmux workspace tab named "<repo>:feature/auth-jwt"
#  → launches Claude Code there

# work happens in the new workspace, commits accumulate on feature/auth-jwt
# when done, from inside the feature workspace:

/cmux:finish-feature      # merge + cleanup
# or
/cmux:abandon-feature     # discard + cleanup
```

`.worktrees/` should be in your repo's `.gitignore`. `/cmux:start-feature` adds it
automatically if missing.

#### Worktree lifecycle hooks

`/cmux:start-feature` does two things to make the new worktree usable immediately:

1. **Symlinks dev-time secret/config files** from the main worktree, when present:
   `.env`, `.env.local`, `.env.development`, `.env.development.local`, `.envrc`.
   Each link is relative, so they survive directory moves, and edits made in
   either location propagate (one shared source of truth). Production env files
   are intentionally not symlinked.

2. **Runs an optional `post-create` hook** if `<repo>/.cmux/post-create.sh` exists
   and is executable. The hook runs in the new workspace's terminal (so its
   output is visible), with cwd set to the feature worktree and these env vars
   exported: `CMUX_FEATURE_SLUG`, `CMUX_FEATURE_BRANCH`, `CMUX_FEATURE_WORKTREE`,
   `CMUX_MAIN_WORKTREE`. Claude Code launches after the hook succeeds.

   Example `.cmux/post-create.sh`:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   uv sync
   pnpm install --frozen-lockfile
   ```

`/cmux:finish-feature` and `/cmux:abandon-feature` look for a symmetric **`pre-destroy`
hook** at `<repo>/.cmux/pre-destroy.sh`. If present and executable, it runs from
the feature worktree (cwd = feature worktree) with the same `CMUX_FEATURE_*`
env vars, *before* the worktree is removed. Use it to tear down state that
`post-create.sh` created — stop a dev server, drop a temp database, prune
containers. If the hook exits non-zero the cleanup is aborted and the worktree
is left intact, so the user can fix the script and retry.

Example `.cmux/pre-destroy.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
docker compose -p "cmux-${CMUX_FEATURE_SLUG}" down -v
```

Commit both files under `.cmux/` (`chmod +x` them) so every worktree gets the
same lifecycle. The plugin never auto-detects package managers or services —
what "setup" and "teardown" mean is your project's call.

## How Claude Uses cmux Automatically

Claude detects cmux via the `CMUX_WORKSPACE_ID` environment variable. If it's not set (i.e. you're not in cmux), all cmux features are silently skipped — this plugin causes zero noise in other environments.

When inside cmux, Claude will:

- **Open a new workspace** when about to create a git worktree or launch an independent sub-agent
- **Maintain a progress bar** in the sidebar during tasks that take more than ~30 seconds
- **Open a browser split** when it needs to visually verify UI or test a dev server
- **Send a notification** at genuine handoff points — not after every step

## Forcing Reliable Activation

To ensure Claude actually triggers the cmux skill before every relevant action — especially before dispatching parallel sub-agents, where other skills can take precedence — add a `SessionStart` hook to `~/.claude/settings.json`. It injects an explicit reminder whenever `CMUX_WORKSPACE_ID` is set.

The simplest way is to ask Claude to install it for you — e.g. *"install the cmux SessionStart hook in my user settings"*. Claude will merge the snippet below into `~/.claude/settings.json` (preserving your existing config), validate the JSON, and pipe-test the command. Otherwise, paste it in by hand:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "if [ -n \"$CMUX_WORKSPACE_ID\" ]; then jq -n '{hookSpecificOutput:{hookEventName:\"SessionStart\",additionalContext:\"You are running inside cmux (CMUX_WORKSPACE_ID is set). You MUST invoke the cmux:cmux skill via the Skill tool BEFORE: dispatching parallel sub-agents (Agent tool), launching long-running tasks (>30s), browser-based testing, or any work that benefits from sidebar progress reporting and attention notifications. Do this proactively without waiting for the user to ask.\"}}'; fi"
          }
        ]
      }
    ]
  }
}
```

Outside cmux the hook outputs nothing and exits 0, so it is safe to keep enabled globally. After editing, open `/hooks` once or restart Claude Code for the watcher to pick up the change.

## Works With Superpowers

If you have the [Superpowers plugin](https://claude.com/plugins/superpowers) installed, the cmux skill is aware of its workflow phases:

- `using-git-worktrees` → new cmux workspace named after the branch
- `subagent-driven-development` → live progress bar per task
- `finishing-a-development-branch` → notification that review is ready

## File Structure

```
cmux-plugin/
├── .claude-plugin/
│   └── plugin.json            # Plugin manifest
├── skills/
│   └── cmux/
│       ├── SKILL.md           # Core skill — teaches Claude when/how to use cmux
│       └── references/        # On-demand details (browser, feature lifecycle, ...)
├── hooks/
│   └── hooks.json             # Hook event declarations
├── scripts/
│   ├── cmux-session-start.sh  # Renames workspace tab on session start
│   └── cmux-notify.sh         # Forwards sub-agent completions and Notification events to cmux
├── commands/
│   ├── status.md              # /cmux:status
│   ├── open-browser.md        # /cmux:open-browser
│   ├── start-feature.md       # /cmux:start-feature
│   ├── finish-feature.md      # /cmux:finish-feature
│   └── abandon-feature.md     # /cmux:abandon-feature
├── CHANGELOG.md
└── README.md
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE).

## Author

Maintained by Alexandre Roman ([@alexandreroman](https://github.com/alexandreroman)).

Forked from [hopchouinard/cmux-plugin](https://github.com/hopchouinard/cmux-plugin) — original work by Patrick Chouinard ([@hopchouinard](https://github.com/hopchouinard)), AI Acceleration Specialist · [Wepoint](https://wepoint.ca).
