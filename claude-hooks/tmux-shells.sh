#!/usr/bin/env bash
# Sets each tmux session's @agent_shells option to the number of an agent's Bash tool shells still
# running in it and the age of the oldest ("2 14m"), or unsets it when there are none. A shell
# counts when it was started from ~/.claude/shell-snapshots by a process that is a pane's process
# or that pane process's child. It never prints, so the #() in tmux.conf's status line that runs
# it every status-interval adds nothing to the bar.

command -v tmux >/dev/null 2>&1 || exit 0

panes=$(tmux list-panes -a -F '#{session_id} #{pane_pid}' 2>/dev/null) || exit 0
procs=$(ps -axo pid=,ppid=,etime=,command=)

# Lines of "session_id count oldest_seconds", one per session with at least one shell.
counts=$(awk '
	function secs(t,   d, n, p, s) {
		d = 0
		if (index(t, "-")) { split(t, p, "-"); d = p[1]; t = p[2] }
		n = split(t, p, ":"); s = 0
		for (i = 1; i <= n; i++) s = s * 60 + p[i]
		return d * 86400 + s
	}
	FNR == NR { sess[$2] = $1; next }
	{ parent[$1] = $2 }
	$0 ~ /\/\.claude\/shell-snapshots\// { shell[$1] = $2; age[$1] = secs($3) }
	END {
		for (p in shell) {
			o = shell[p]
			s = (o in sess) ? sess[o] : ((parent[o] in sess) ? sess[parent[o]] : "")
			if (s == "") continue
			c[s]++
			if (age[p] > m[s]) m[s] = age[p]
		}
		for (s in c) print s, c[s], m[s]
	}
' <(printf '%s\n' "$panes") <(printf '%s\n' "$procs"))

human() {
	if [ "$1" -ge 3600 ]; then echo "$(($1 / 3600))h"
	elif [ "$1" -ge 60 ]; then echo "$(($1 / 60))m"
	else echo "${1}s"; fi
}

tmux list-sessions -F '#{session_id}' 2>/dev/null | while read -r s; do
	line=$(grep "^$s " <<<"$counts")
	if [ -n "$line" ]; then
		set -- $line
		tmux set -t "$s" @agent_shells "$2 $(human "$3")"
	else
		tmux set -u -t "$s" @agent_shells
	fi
done >/dev/null 2>&1
exit 0
