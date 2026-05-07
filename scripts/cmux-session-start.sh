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
# 1. Git repo root name  (most reliable across your multi-project setup)
# 2. Current directory name  (fallback for non-git directories)
GIT_ROOT=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$GIT_ROOT" ]; then
    PROJECT_NAME=$(basename "$GIT_ROOT")
else
    PROJECT_NAME=$(basename "$PWD")
fi

# Sanitize
PROJECT_NAME=$(echo "$PROJECT_NAME" | tr -d '\n' | sed 's|/|-|g')
[ -z "$PROJECT_NAME" ] && PROJECT_NAME="claude"

# ── Get current branch ─────────────────────────────────────────────────────────
GIT_BRANCH=$(git -C "$PWD" rev-parse --abbrev-ref HEAD 2>/dev/null)

# ── Detect linked worktree ─────────────────────────────────────────────────────
# In the main worktree, --git-dir and --git-common-dir resolve to the same path.
# In a linked worktree they differ. Distinguish so parallel feature workspaces
# created by /cmux:start-feature are visually distinct in the sidebar.
GIT_DIR_LOCAL=$(git -C "$PWD" rev-parse --git-dir 2>/dev/null)
GIT_DIR_COMMON=$(git -C "$PWD" rev-parse --git-common-dir 2>/dev/null)
if [ -n "$GIT_DIR_LOCAL" ] && [ -n "$GIT_DIR_COMMON" ] && [ "$GIT_DIR_LOCAL" != "$GIT_DIR_COMMON" ] && [ -n "$GIT_BRANCH" ]; then
    WORKSPACE_NAME="${PROJECT_NAME}:${GIT_BRANCH}"
else
    WORKSPACE_NAME="$PROJECT_NAME"
fi

# ── Rename the workspace tab ───────────────────────────────────────────────────
cmux rename-workspace --workspace "$CMUX_WORKSPACE_ID" "$WORKSPACE_NAME" 2>/dev/null

# ── Sidebar status entry ───────────────────────────────────────────────────────
if [ -n "$GIT_BRANCH" ]; then
    STATUS="⚡ ${PROJECT_NAME} · ${GIT_BRANCH}"
else
    STATUS="⚡ ${PROJECT_NAME}"
fi

cmux log --level info --source "claude" -- "$STATUS" 2>/dev/null

exit 0
