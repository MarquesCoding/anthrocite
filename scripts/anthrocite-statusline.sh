#!/bin/sh
# Anthrocite statusLine bridge.
#
# Claude Code pipes a JSON status blob to this command on stdin (per session).
# We persist one file per session_id so the Anthrocite app can track every
# concurrent session, then print a compact status line.

input=$(cat)
dir="$HOME/.claude/anthrocite-status"
mkdir -p "$dir" 2>/dev/null

sid=$(printf '%s' "$input" | /usr/bin/jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && sid="unknown"
tmp="$dir/.$sid.tmp"
printf '%s' "$input" > "$tmp" 2>/dev/null && mv "$tmp" "$dir/$sid.json" 2>/dev/null

printf '%s' "$input" | /usr/bin/jq -r '
  [ (.model.display_name // empty),
    (if .rate_limits.five_hour.used_percentage != null
       then "5h \(.rate_limits.five_hour.used_percentage | floor)%" else empty end),
    (if .rate_limits.seven_day.used_percentage != null
       then "7d \(.rate_limits.seven_day.used_percentage | floor)%" else empty end)
  ] | join("  ·  ")' 2>/dev/null
