#!/usr/bin/env bash
# Marks the tmux session this agent runs in as waiting on the user, by setting the session option
# @agent_waiting that tmux.conf's status bar colours: "1" (orange) when nothing is left running,
# "bg" (blue) when a Stop's background_tasks still lists running subagents or shells. "off" unsets
# it, except from a subagent's own hooks (input with an agent_id), so a background subagent's tool
# calls don't clear the main agent's state. Outside tmux it does nothing. It never prints, so
# nothing it does reaches the agent's context.
# Usage: tmux-turn.sh on|off   (hook input JSON on stdin)

input=$(cat)

[ -n "$TMUX_PANE" ] && command -v tmux >/dev/null 2>&1 || exit 0

session=$(tmux display -p -t "$TMUX_PANE" '#{session_id}' 2>/dev/null) || exit 0
field() { command -v jq >/dev/null 2>&1 && jq -r "$1" <<<"$input" 2>/dev/null; }

case "$1" in
	on)
		state=1
		running=$(field '[.background_tasks[]? | select(.status == "running")] | length')
		[ "${running:-0}" -gt 0 ] 2>/dev/null && state=bg
		tmux set -t "$session" @agent_waiting "$state"
		;;
	off)
		[ -n "$(field '.agent_id // empty')" ] && exit 0
		tmux set -u -t "$session" @agent_waiting
		;;
esac >/dev/null 2>&1

# Redraw every client's status bar now rather than at the next status-interval.
tmux list-clients -F '#{client_name}' 2>/dev/null | while read -r c; do
	tmux refresh-client -S -t "$c" >/dev/null 2>&1
done
exit 0
