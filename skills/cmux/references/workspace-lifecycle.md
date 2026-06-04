# Workspace lifecycle skills

The three skills below (`/cmux:new-workspace`, `/cmux:close-workspace`,
`/cmux:cancel-workspace`) all operate on the same layout: a `feature/<slug>`
branch checked out under `.worktrees/<slug>` with a matching cmux workspace
named `<repo-basename>-<slug>`. The `feature/<slug>` prefix is a short-lived
branch convention — the workspace itself can host any kind of isolated work
(a feature, a code review, a spike, a refactor).

Every isolated workspace is grouped under a collapsible `📁 <repo-basename>`
sidebar folder tied to the workspace it was spawned from (its **origin**).
There is one folder per origin. The folder's header is a dedicated placeholder
workspace cmux spawns as the group's anchor; the origin and each spawned slice
are members under it. This follows cmux's group model, where the anchor is a
dedicated, freshly-spawned workspace that *is* the header — an existing
workspace is never promoted to anchor (see
[cmux's workspace-groups doc](https://github.com/manaflow-ai/cmux/blob/main/docs/workspace-groups.md)).
When a slice is closed or cancelled and only the placeholder header and the
origin are left, the folder is dissolved (its anchor is closed, the origin
preserved) so a lone workspace never sits inside an empty folder. If the user
is on a branch
they made by hand and there's no matching cmux workspace, suggest the
matching skill but verify the preconditions in the skill file
before invoking — don't retrofit the cleanup logic onto an unrelated branch.

## `/cmux:new-workspace <slug>`

Trigger as soon as the user describes a substantial piece of work that
benefits from its own isolated workspace ("new feature", "let's add X",
"build a Y", "implement Z", "review this PR", "spike <something>",
"let's work on Z"), and you are in the main worktree of a cmux-enabled
repo. Prefer this over editing the main worktree directly.

Creates a `feature/<slug>` worktree under `.worktrees/<slug>` and opens a new
cmux workspace named `<repo-basename>-<slug>` with Claude Code running inside
it, grouped under the origin's `📁 <repo-basename>` sidebar folder.

Skip for trivial fixes, tiny doc tweaks, or when the user is already inside
an isolated worktree.

## `/cmux:close-workspace`

Trigger when work inside an isolated worktree is complete and the user signals
integration ("merge it", "ship it", "this is done", "wrap up", "review
approved", or tests/checks pass and they want to land it).

Merges into the base branch (fast-forward when possible), removes the worktree
and branch, and closes the current cmux workspace. If the origin's folder is
left holding only its placeholder header and the origin, it dissolves the
folder.

## `/cmux:cancel-workspace`

Trigger when the user wants to throw the isolated workspace away ("abandon",
"discard", "scrap this", "start over", "this isn't working").

Destructive: removes the worktree, force-deletes the branch, and closes the
workspace. Like `/cmux:close-workspace`, it dissolves the origin's folder when
only its placeholder header and the origin remain. Always confirm via
`AskUserQuestion` before running, even in auto mode.
