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

# fixkeys: turn off keyboard modes a crashed program left on, so ctrl keys work again
fixkeys() { printf '\e[<u\e[>4;0m'; }

# g: short for git
alias g=git
