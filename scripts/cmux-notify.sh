#!/bin/bash
# cmux-notify.sh
# Routes Claude Code hook events to cmux notifications.
#
# - PostToolUse(Task): notifies when a sub-agent finishes
# - Notification: intercepts Claude Code's idle notification.
#   Registering this hook *replaces* the default OS notification, so
#   the noisy "Claude is waiting for your input" can be suppressed
#   silently while genuine permission prompts are forwarded to cmux.
#
# Stop events are intentionally not handled: cmux already shows a
# native end-of-turn notification with the response content.
#
# Silently exits if not running inside cmux.

# ── Guard ──────────────────────────────────────────────────────────────────────
[ -S "${CMUX_SOCKET_PATH:-/tmp/cmux.sock}" ] || exit 0
command -v cmux &>/dev/null                  || exit 0
command -v jq   &>/dev/null                  || exit 0

# ── Parse event ───────────────────────────────────────────────────────────────
EVENT=$(cat)
EVENT_TYPE=$(echo "$EVENT"   | jq -r '.hook_event_name // .event // "unknown"')
TOOL=$(echo "$EVENT"         | jq -r '.tool_name // ""')
AGENT_TYPE=$(echo "$EVENT"   | jq -r '.tool_input.subagent_type // "general-purpose"')
AGENT_DESC=$(echo "$EVENT"   | jq -r '.tool_input.description // ""')
MESSAGE=$(echo "$EVENT"      | jq -r '.message // ""')

# ── Notify by event type ───────────────────────────────────────────────────────
case "$EVENT_TYPE" in
    "PostToolUse")
        if [ "$TOOL" = "Task" ]; then
            if [ -n "$AGENT_DESC" ]; then
                BODY="$AGENT_TYPE: $AGENT_DESC"
            else
                BODY="$AGENT_TYPE finished"
            fi
            cmux notify \
                --title "Claude Code" \
                --subtitle "Sub-agent finished" \
                --body  "$BODY" \
                2>/dev/null
        fi
        ;;
    "Notification")
        # Idle "waiting for your input" is redundant with cmux's native
        # end-of-turn notification — suppress it silently.
        if [[ "$MESSAGE" == *"waiting for your input"* ]]; then
            exit 0
        fi
        # Anything else (typically permission requests) is genuine —
        # forward it to cmux so the user actually sees it.
        if [ -n "$MESSAGE" ]; then
            cmux notify \
                --title "Claude Code" \
                --body  "$MESSAGE" \
                2>/dev/null
        fi
        ;;
esac

exit 0
