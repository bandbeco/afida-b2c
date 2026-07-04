#!/usr/bin/env bash
# PostToolUse hook: append a line to docs/worklog-auto.md when a session uses a
# non-code billable tool (Datafast CLI, Klaviyo MCP, or GSC/analytics MCP).
# Dedupes to one line per tool-signal per day. Fails open (never blocks the tool).
#
# Reads the hook payload JSON on stdin. See docs/worklog.md for the wider system.
set -euo pipefail

# Resolve the log path relative to this script (repo/.claude/hooks -> repo/docs).
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
log="$repo/docs/worklog-auto.md"

# Read stdin once.
payload="$(cat)"

tool="$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null || echo "")"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")"

# Map the tool call to a coarse category (one worklog line per category per day).
category=""
case "$tool" in
  mcp__klaviyo__*)              category="klaviyo" ;;
  mcp__claude_ai_Windsor_ai__*) category="gsc/analytics" ;;
  *datafast*|*Datafast*)        category="datafast" ;;
  Bash)
    case "$cmd" in
      *datafast*|*"@datafast/cli"*) category="datafast" ;;
    esac
    ;;
esac

# Not a billable-signal tool: do nothing.
[ -n "$category" ] || exit 0

# Only proceed if the log file exists (don't create it from a hook).
[ -f "$log" ] || exit 0

today="$(date '+%Y-%m-%d')"
now="$(date '+%H:%M')"

# Dedupe on (day, category): skip if a line for today already carries this category.
if grep -E "^$today  " "$log" 2>/dev/null | grep -qF "  $category" ; then
  exit 0
fi

printf '%s  %s  %s\n' "$today" "$now" "$category" >> "$log"
exit 0
