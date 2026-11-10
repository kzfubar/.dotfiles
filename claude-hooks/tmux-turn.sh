#!/usr/bin/env bash
# Marks the tmux session this agent runs in as waiting on the user, by setting the session option
# @agent_waiting that tmux.conf's status bar colours: "1" (orange) when nothing is left running,
# "bg" (blue) when a Stop's background_tasks still lists running subagents or shells. "off" unsets
# it, except from a subagent's own hooks (input with an agent_id), so a background subagent's tool
# calls don't clear the main agent's state. agent-start and agent-stop keep one marker file per
# running subagent in $TMPDIR/tmux-turn-agents/<tmux session id>/, holding the path of its
# transcript; tmux-shells.sh reads them to turn a stale blue back to orange. Outside tmux it does
# nothing. It never prints, so nothing it does reaches the agent's context.
# Usage: tmux-turn.sh on|off|agent-start|agent-stop   (hook input JSON on stdin)

input=$(cat)

[ -n "$TMUX_PANE" ] && command -v tmux >/dev/null 2>&1 || exit 0

session=$(tmux display -p -t "$TMUX_PANE" '#{session_id}' 2>/dev/null) || exit 0
field() { command -v jq >/dev/null 2>&1 && jq -r "$1" <<<"$input" 2>/dev/null; }
agents="${TMPDIR:-/tmp}/tmux-turn-agents/${session#\$}"

# The main agent's transcript, which tmux-shells.sh uses to find the session's subagent transcripts.
case "$1" in on | off)
	transcript=$(field '.transcript_path // empty')
	[ -n "$transcript" ] && [ -z "$(field '.agent_id // empty')" ] &&
		tmux set -t "$session" @agent_transcript "$transcript" >/dev/null 2>&1
	;;
esac

case "$1" in
	on)
		state=1
		running=$(field '[.background_tasks[]? | select(.status == "running")] | length')
		[ "${running:-0}" -gt 0 ] 2>/dev/null && state=bg
		subagents=$(field '[.background_tasks[]? | select(.status == "running" and .type == "subagent")] | length')
		[ "$(field .hook_event_name)" = Stop ] && [ "${subagents:-1}" = 0 ] && rm -rf "$agents"
		tmux set -t "$session" @agent_waiting "$state"
		;;
	off)
		[ -n "$(field '.agent_id // empty')" ] && exit 0
		[ "$(field .hook_event_name)" = SessionEnd ] && rm -rf "$agents"
		tmux set -u -t "$session" @agent_waiting
		;;
	agent-start)
		id=$(field '.agent_id // empty')
		parent=$(field '.transcript_path // empty')
		[ -n "$id" ] && mkdir -p "$agents" &&
			printf '%s\n' "${parent:+${parent%.jsonl}/subagents/agent-$id.jsonl}" >"$agents/$id"
		exit 0
		;;
	agent-stop)
		id=$(field '.agent_id // empty')
		[ -n "$id" ] && rm -f "$agents/$id"
		exit 0
		;;
esac >/dev/null 2>&1

# Redraw every client's status bar now rather than at the next status-interval.
tmux list-clients -F '#{client_name}' 2>/dev/null | while read -r c; do
	tmux refresh-client -S -t "$c" >/dev/null 2>&1
done
exit 0
