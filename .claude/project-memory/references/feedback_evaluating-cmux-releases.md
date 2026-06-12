---
name: "Evaluating new cmux releases"
description: "How to assess whether a new cmux version requires changes to this plugin"
type: feedback
---

# Evaluating new cmux releases

When a new cmux version is installed and the question is "what's new / do we
need to update the project", evaluate impact on the plugin rather than bumping
anything. The default answer is "no change needed": most cmux releases are app /
iOS / UI work that does not touch the CLI surface the skills depend on.

**Why:** The plugin's skills document the cmux CLI behaviorally and pin no
version by design (see the "Writing skill docs" section of CLAUDE.md). Version
numbers and comparative wording rot, so the docs must stay timeless.

**How to apply:**
- Read the release notes — cmux is open source at github.com/manaflow-ai/cmux,
  releases at `/releases/tag/v<version>`; the GitHub link is also printed by
  `cmux welcome`.
- Check only whether the CLI/socket surface the skills rely on changed: workspace
  lifecycle, worktree hooks, `cmux browser ...`, and workspace-grouping
  (`cmux workspace-group ...`). Verify against the installed CLI with
  `cmux <cmd> --help` / `cmux capabilities`, not the notes alone.
- `skills/cmux/references/browser-automation.md` defers to `cmux browser --help`,
  so new browser subcommands rarely need doc edits unless the documented common
  path changes.
- Never introduce a version number or comparative wording when updating docs.
