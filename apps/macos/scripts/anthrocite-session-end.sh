#!/bin/sh
# Anthrocite SessionEnd hook.
#
# Claude Code runs this when a session ends. We delete that session's status
# file so it disappears from the Anthrocite menu immediately (instead of
# lingering until it goes stale).

input=$(cat)
sid=$(printf '%s' "$input" | /usr/bin/jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] && rm -f "$HOME/.claude/anthrocite-status/$sid.json"
exit 0
