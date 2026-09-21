#!/bin/sh
# PreToolUse/Bash hook. Rejects git commits carrying Claude attribution trailers.
# Exit 2 blocks the tool call and returns stderr to Claude; exit 0 allows it.

cmd=$(jq -r '.tool_input.command // ""')

case "$cmd" in
	*"git commit"*|*"git "*" commit"*) ;;
	*) exit 0 ;;
esac

if printf '%s' "$cmd" | grep -qiE 'co-authored-by:[[:space:]]*claude|generated with .{0,3}claude code|claude\.ai/code|claude-session:'; then
	echo "Blocked: this commit message carries Claude attribution. Remove the trailer (Co-Authored-By, Generated with Claude Code, or a claude.ai session link) and commit again." >&2
	exit 2
fi

exit 0
