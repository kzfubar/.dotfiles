# Settings, aliases and functions shared by zsh (.zshrc) and bash (.bashrc); sourced, so it
# must stay valid in both shells.

export PATH="$PATH:$HOME/.local/bin"
export EDITOR=vim

# user-harness telemetry settings, written by `uh telemetry setup`
[ -f "$HOME/.config/user-harness/telemetry.env" ] && source "$HOME/.config/user-harness/telemetry.env"

# cl: run claude in ~/scratch, or in the given dir. Extra args go to claude.
# Outside tmux it starts a new tmux session named after the dir, or name-2, name-3, ... when that
# name is taken. Runs claude directly when already inside tmux, when tmux is not installed, or when
# CL_NO_TMUX is set.
cl() {
  local dir name base n
  if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
    dir="$1"; shift
  else
    dir="$HOME/scratch"
    mkdir -p "$dir"
  fi
  if [ -n "$TMUX" ] || [ -n "$CL_NO_TMUX" ] || ! command -v tmux >/dev/null 2>&1; then
    (cd "$dir" && claude "$@")
    return
  fi
  dir="$(cd "$dir" && pwd)" || return
  base="$(basename "$dir" | tr '.:' '__')"
  name="$base"
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
