# CMUX-PLUGIN — for Claude Code

Integrates [Claude Code](https://claude.ai/code) with [cmux](https://cmux.com) — the native macOS terminal built for AI coding agents.

## What It Does

| Feature | How it works |
|---|---|
| **Auto workspace naming** | `SessionStart` hook renames the cmux sidebar tab to your git repo name + branch on every session |
| **Sub-agent notifications** | `PostToolUse(Task)` hook fires a cmux notification when a sub-agent finishes. End-of-turn notifications are handled natively by cmux, so the plugin does not duplicate them |
| **Notification forwarding** | `Notification` hook forwards Claude Code events (permission prompts, idle pings, etc.) to cmux as native notifications, replacing the default OS pop-ups |
| **Sidebar progress** | The cmux skill teaches Claude to report long-running task progress as a live progress bar in the sidebar |
| **Browser split automation** | Claude proactively opens a browser split when it needs to visually verify your dev server or debug UI |
| **Isolated workspace workflow** | `/cmux:new-workspace`, `/cmux:close-workspace`, `/cmux:cancel-workspace` — git worktree + isolated cmux workspace per piece of work (feature, code review, spike, refactor), with a Claude Code instance per worktree |
| **Superpowers integration** | When the [Superpowers plugin](https://claude.com/plugins/superpowers) triggers `using-git-worktrees`, Claude opens a new cmux workspace for the branch automatically |
| **Skills** | `/cmux:status`, `/cmux:open-browser`, `/cmux:new-workspace`, `/cmux:close-workspace`, `/cmux:cancel-workspace` — each invocable as a slash command or auto-invoked by Claude when the context matches |

## Requirements

- macOS 14.0+
- [cmux](https://cmux.com) installed (`brew tap manaflow-ai/cmux && brew install --cask cmux`)
- cmux CLI symlinked: `sudo ln -sf "/Applications/cmux.app/Contents/Resources/bin/cmux" /usr/local/bin/cmux`
- `jq` installed (`brew install jq`)

## Installation

```bash
# In Claude Code
/plugin marketplace add alexandreroman/cc-plugins
/plugin install cmux@cc-plugins
/reload-plugins
```

## Skills

Each ships as a skill under `skills/`. Invoke it manually as a slash command
(`/cmux:<name>`), or let Claude invoke it automatically when the conversation
matches the skill's description.

| Skill | Description |
|---|---|
| `/cmux:status` | Show current workspace, panes, surfaces, and sidebar log |
| `/cmux:open-browser [url]` | Open a browser split (defaults to `localhost:3000`) |
| `/cmux:new-workspace <slug>` | Create a `feature/<slug>` worktree under `.worktrees/<slug>`, open a new cmux workspace, and launch Claude Code in it |
| `/cmux:close-workspace` | Merge the workspace branch into the base branch (fast-forward when possible), remove the worktree and local branch, close the cmux workspace. Run from the isolated worktree |
| `/cmux:cancel-workspace` | Discard the workspace: force-remove the worktree, force-delete the branch, close the cmux workspace. Asks for confirmation. Run from the isolated worktree |

### Isolated workspace workflow

```bash
# from the main repo workspace
/cmux:new-workspace auth-jwt
#  → creates branch feature/auth-jwt
#  → creates worktree at <repo>/.worktrees/auth-jwt
#  → opens a new cmux workspace tab named "<repo>-auth-jwt"
#  → launches Claude Code there

# work happens in the new workspace, commits accumulate on feature/auth-jwt
# when done, from inside the isolated workspace:

/cmux:close-workspace     # merge + cleanup
# or
/cmux:cancel-workspace    # discard + cleanup
```

The slug can describe any kind of isolated work — `auth-jwt` for a feature,
`review-pr-42` for a code review, `spike-graphql` for an experiment. The
underlying branch is always `feature/<slug>` regardless (a short-lived
branch-name convention; not a statement about the kind of work).

`.worktrees/` should be in your repo's `.gitignore`. `/cmux:new-workspace` adds it
automatically if missing.

#### Worktree lifecycle hooks

`/cmux:new-workspace` does two things to make the new worktree usable immediately:

1. **Symlinks dev-time secret/config files** from the main worktree, when present:
   `.env`, `.env.local`, `.env.development`, `.env.development.local`, `.envrc`.
   Each link is relative, so they survive directory moves, and edits made in
   either location propagate (one shared source of truth). Production env files
   are intentionally not symlinked.

2. **Runs an optional `post-create` hook** if `<repo>/.cmux/post-create.sh` exists
   and is executable. The hook runs in the new workspace's terminal (so its
   output is visible), with cwd set to the new worktree and these env vars
   exported: `CMUX_FEATURE_SLUG`, `CMUX_FEATURE_BRANCH`, `CMUX_FEATURE_WORKTREE`,
   `CMUX_MAIN_WORKTREE` (names kept stable for backwards compatibility with
   existing project hook scripts). Claude Code launches after the hook succeeds.

   Example `.cmux/post-create.sh`:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   uv sync
   pnpm install --frozen-lockfile
   ```

`/cmux:close-workspace` and `/cmux:cancel-workspace` look for a symmetric **`pre-destroy`
hook** at `<repo>/.cmux/pre-destroy.sh`. If present and executable, it runs from
the isolated worktree (cwd = the worktree) with the same `CMUX_FEATURE_*`
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
│   ├── cmux/
│   │   ├── SKILL.md           # Core skill — teaches Claude when/how to use cmux
│   │   └── references/        # On-demand details (browser, workspace lifecycle, ...)
│   ├── status/SKILL.md           # /cmux:status
│   ├── open-browser/SKILL.md     # /cmux:open-browser
│   ├── new-workspace/SKILL.md    # /cmux:new-workspace
│   ├── close-workspace/SKILL.md  # /cmux:close-workspace
│   └── cancel-workspace/SKILL.md # /cmux:cancel-workspace
├── hooks/
│   └── hooks.json             # Hook event declarations
├── scripts/
│   ├── cmux-session-start.sh  # Renames workspace tab on session start
│   └── cmux-notify.sh         # Forwards sub-agent completions and Notification events to cmux
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
