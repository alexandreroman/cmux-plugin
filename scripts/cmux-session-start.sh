#!/bin/bash
# cmux-session-start.sh
# Fires on Claude Code SessionStart.
# Renames the cmux workspace tab to the current project name and
# logs a status entry in the sidebar showing project + git branch.
#
# Silently exits if not running inside cmux.

# ── Guard ──────────────────────────────────────────────────────────────────────
[ -S "${CMUX_SOCKET_PATH:-/tmp/cmux.sock}" ] || exit 0
[ -n "$CMUX_WORKSPACE_ID" ]                  || exit 0
command -v cmux &>/dev/null                  || exit 0

# ── Derive project name ────────────────────────────────────────────────────────
# Project name = basename of the *main* worktree's root, even when running
# inside a linked worktree. We resolve git-common-dir (which always points at
# the main repo's .git) and take its parent directory.
GIT_DIR_LOCAL=$(git -C "$PWD" rev-parse --path-format=absolute --git-dir 2>/dev/null)
GIT_DIR_COMMON_ABS=$(git -C "$PWD" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
GIT_BRANCH=$(git -C "$PWD" rev-parse --abbrev-ref HEAD 2>/dev/null)

if [ -n "$GIT_DIR_COMMON_ABS" ]; then
    MAIN_ROOT=$(dirname "$GIT_DIR_COMMON_ABS")
    PROJECT_NAME=$(basename "$MAIN_ROOT")
else
    PROJECT_NAME=$(basename "$PWD")
fi

# Sanitize
PROJECT_NAME=$(echo "$PROJECT_NAME" | tr -d '\n' | sed 's|/|-|g')
[ -z "$PROJECT_NAME" ] && PROJECT_NAME="claude"

# ── Detect linked worktree ─────────────────────────────────────────────────────
# In the main worktree, --git-dir and --git-common-dir resolve to the same path.
# In a linked worktree they differ. When inside a linked worktree, append the
# branch leaf (last segment, e.g. `feature/2pc` → `2pc`) so parallel feature
# workspaces are visually distinct in the sidebar — and match the naming
# convention used by /cmux:start-feature.
if [ -n "$GIT_DIR_LOCAL" ] && [ -n "$GIT_DIR_COMMON_ABS" ] && [ "$GIT_DIR_LOCAL" != "$GIT_DIR_COMMON_ABS" ] && [ -n "$GIT_BRANCH" ]; then
    BRANCH_SLUG="${GIT_BRANCH##*/}"
    WORKSPACE_NAME="${PROJECT_NAME}-${BRANCH_SLUG}"
else
    WORKSPACE_NAME="$PROJECT_NAME"
fi

# ── Rename the workspace tab ───────────────────────────────────────────────────
# Respect names set by the caller via `cmux new-workspace --name <name>`. If the
# workspace already has a customized name (e.g. `<parent>-process-url-<id>`),
# don't clobber it with the default derived from the repo basename.
CURRENT_NAME=$(cmux list-workspaces 2>/dev/null \
    | sed -E 's/^[* ] +//' \
    | awk -F'  +' -v ref="$CMUX_WORKSPACE_ID" '$1 == ref { print $2 }')

if [ -n "$CURRENT_NAME" ] && [ "$CURRENT_NAME" != "$WORKSPACE_NAME" ] && [ "$CURRENT_NAME" != "claude" ]; then
    : # custom name already set — leave it alone
else
    cmux rename-workspace --workspace "$CMUX_WORKSPACE_ID" "$WORKSPACE_NAME" 2>/dev/null
fi

# ── Sidebar status entry ───────────────────────────────────────────────────────
if [ -n "$GIT_BRANCH" ]; then
    STATUS="⚡ ${PROJECT_NAME} · ${GIT_BRANCH}"
else
    STATUS="⚡ ${PROJECT_NAME}"
fi

cmux log --level info --source "claude" -- "$STATUS" 2>/dev/null

exit 0
