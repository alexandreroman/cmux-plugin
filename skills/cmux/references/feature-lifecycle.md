# Feature lifecycle slash commands

The three commands below (`/cmux:start-feature`, `/cmux:finish-feature`,
`/cmux:abandon-feature`) assume the worktree layout produced by
`/cmux:start-feature` — i.e. a `feature/<slug>` branch checked out under
`.worktrees/<slug>` with a matching cmux workspace named
`<repo-basename>-<slug>`. If the user is on a feature branch they made by
hand, suggest the matching slash command but verify the preconditions in
the command file before invoking — don't retrofit the cleanup logic onto an
unrelated branch.

## `/cmux:start-feature <slug>`

Trigger as soon as the user describes a new feature or substantive new piece
of work ("new feature", "let's add X", "build a Y", "implement Z",
"I want to create…"), and you are in the main worktree of a cmux-enabled
repo. Prefer this over editing the main worktree directly.

Creates a `feature/<slug>` worktree under `.worktrees/<slug>` and opens a new
cmux workspace named `<repo-basename>-<slug>` with Claude Code running inside
it.

Skip for trivial fixes, tiny doc tweaks, or when the user is already inside
a feature worktree.

## `/cmux:finish-feature`

Trigger when work inside a feature worktree is complete and the user signals
integration ("merge it", "ship it", "this is done", "wrap up", or tests/checks
pass and they want to land it).

Merges into the base branch (fast-forward when possible), removes the worktree
and branch, and closes the current cmux workspace.

## `/cmux:abandon-feature`

Trigger when the user wants to throw the feature away ("abandon", "discard",
"scrap this", "start over", "this isn't working").

Destructive: removes the worktree, force-deletes the branch, and closes the
workspace. Always confirm via `AskUserQuestion` before running, even in auto
mode.
