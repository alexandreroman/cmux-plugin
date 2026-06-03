# Workspace lifecycle slash commands

The three commands below (`/cmux:new-workspace`, `/cmux:close-workspace`,
`/cmux:cancel-workspace`) all operate on the same layout: a `feature/<slug>`
branch checked out under `.worktrees/<slug>` with a matching cmux workspace
named `<repo-basename>-<slug>`. The `feature/<slug>` prefix is a short-lived
branch convention — the workspace itself can host any kind of isolated work
(a feature, a code review, a spike, a refactor).

Every isolated workspace is grouped under the workspace it was spawned from
(its **origin**). There is one sidebar group per origin: the origin is the
group's anchor — the group header *is* the origin's sidebar row — and each
workspace spawned from it joins that same group. When a slice is closed or
cancelled and only the origin is left, the group is dissolved so a lone
workspace never sits inside a one-member group. If the user is on a branch
they made by hand and there's no matching cmux workspace, suggest the
matching slash command but verify the preconditions in the command file
before invoking — don't retrofit the cleanup logic onto an unrelated branch.

## `/cmux:new-workspace <slug>`

Trigger as soon as the user describes a substantial piece of work that
benefits from its own isolated workspace ("new feature", "let's add X",
"build a Y", "implement Z", "review this PR", "spike <something>",
"let's work on Z"), and you are in the main worktree of a cmux-enabled
repo. Prefer this over editing the main worktree directly.

Creates a `feature/<slug>` worktree under `.worktrees/<slug>` and opens a new
cmux workspace named `<repo-basename>-<slug>` with Claude Code running inside
it, grouped under the origin workspace.

Skip for trivial fixes, tiny doc tweaks, or when the user is already inside
an isolated worktree.

## `/cmux:close-workspace`

Trigger when work inside an isolated worktree is complete and the user signals
integration ("merge it", "ship it", "this is done", "wrap up", "review
approved", or tests/checks pass and they want to land it).

Merges into the base branch (fast-forward when possible), removes the worktree
and branch, and closes the current cmux workspace. If the origin's group is
left holding only the origin, it dissolves the group.

## `/cmux:cancel-workspace`

Trigger when the user wants to throw the isolated workspace away ("abandon",
"discard", "scrap this", "start over", "this isn't working").

Destructive: removes the worktree, force-deletes the branch, and closes the
workspace. Like `/cmux:close-workspace`, it dissolves the origin's group when
only the origin remains. Always confirm via `AskUserQuestion` before running,
even in auto mode.
