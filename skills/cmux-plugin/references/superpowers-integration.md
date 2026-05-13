# Superpowers plugin integration

Read this when the Superpowers plugin is active and one of its workflows
triggers. Pair the Superpowers event with the matching cmux action so the
sidebar reflects ambient parallel-work state without the human needing to
actively watch a terminal.

| Superpowers event | cmux action |
|---|---|
| `using-git-worktrees` activates | Open new workspace named after the branch |
| `subagent-driven-development` running | Set + update progress bar per task completed |
| Each sub-agent task completes | `cmux log --level success` with task name |
| `finishing-a-development-branch` activates | `cmux notify` — human review needed |
