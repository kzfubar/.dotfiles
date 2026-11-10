#!/usr/bin/env bash
# Marks the tmux session this agent runs in as waiting on the user (on) or not (off), by setting
# the session option @agent_waiting that tmux.conf's status bar colours orange. Outside tmux it
# does nothing. It never prints, so nothing it does reaches the agent's context.
# Usage: tmux-turn.sh on|off

[ -n "$TMUX_PANE" ] && command -v tmux >/dev/null 2>&1 || exit 0

session=$(tmux display -p -t "$TMUX_PANE" '#{session_id}' 2>/dev/null) || exit 0
case "$1" in
	on) tmux set -t "$session" @agent_waiting 1 ;;
	off) tmux set -u -t "$session" @agent_waiting ;;
esac >/dev/null 2>&1

# Redraw every client's status bar now rather than at the next status-interval.
tmux list-clients -F '#{client_name}' 2>/dev/null | while read -r c; do
	tmux refresh-client -S -t "$c" >/dev/null 2>&1
done
exit 0
