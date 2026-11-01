#!/usr/bin/env bash
# Claude Code status line: model, context use, and plan limits.
# Also saves the rate_limits block to ~/.claude/rate-limits.json so scripts can poll plan usage.
input=$(cat)

limits=$(printf '%s' "$input" | jq -c '.rate_limits // empty' 2>/dev/null)
if [ -n "$limits" ]; then
  out="$HOME/.claude/rate-limits.json"
  printf '%s' "$limits" | jq -c --arg ts "$(date +%s)" '. + {captured_at: ($ts | tonumber)}' > "$out.tmp" \
    && mv -f "$out.tmp" "$out"
fi

printf '%s' "$input" | jq -r '
  def pct(x): if x == null then "–" else "\(x | floor)%" end;
  [ .model.display_name,
    "ctx " + pct(.context_window.used_percentage),
    "5h " + pct(.rate_limits.five_hour.used_percentage),
    "7d " + pct(.rate_limits.seven_day.used_percentage)
  ] | join("  ")'
