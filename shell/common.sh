# Settings, aliases and functions shared by zsh (.zshrc) and bash (.bashrc); sourced, so it
# must stay valid in both shells.

export PATH="$PATH:$HOME/.local/bin"
export EDITOR=vim

# user-harness telemetry settings, written by `uh telemetry setup`
[ -f "$HOME/.config/user-harness/telemetry.env" ] && source "$HOME/.config/user-harness/telemetry.env"

# cl: run claude in ~/scratch, or in the given dir. Extra args go to claude.
cl() {
  local dir
  if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
    dir="$1"; shift
  else
    dir="$HOME/scratch"
    mkdir -p "$dir"
  fi
  (cd "$dir" && claude "$@")
}

# tcl: like cl, but in a new tmux session. tcl [-n name] [dir] [claude args]. The session is named
# after -n or the dir, with -2, -3, ... appended when that name is taken. Inside tmux, or without
# tmux installed, it runs cl instead.
tcl() {
  local dir name n
  if [ "$1" = -n ] && [ $# -ge 2 ]; then
    name="$2"; shift 2
  fi
  if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
    dir="$1"; shift
  else
    dir="$HOME/scratch"
    mkdir -p "$dir"
  fi
  if [ -z "$name" ] && [ "$1" = -n ] && [ $# -ge 2 ]; then
    name="$2"; shift 2
  fi
  if [ -n "$TMUX" ] || ! command -v tmux >/dev/null 2>&1; then
    cl "$dir" "$@"
    return
  fi
  dir="$(cd "$dir" && pwd)" || return
  name="$(printf '%s' "${name:-$(basename "$dir")}" | tr '.:' '__')"
  local base="$name"
  n=2
  while tmux has-session -t "=$name" 2>/dev/null; do
    name="$base-$n"; n=$((n + 1))
  done
  tmux new-session -s "$name" -c "$dir" claude "$@"
}

# fixkeys: turn off keyboard modes a crashed program left on, so ctrl keys work again
fixkeys() { printf '\e[<u\e[>4;0m'; }

# g: short for git
alias g=git
