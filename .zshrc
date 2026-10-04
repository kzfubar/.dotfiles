if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
export PATH="$PATH:$HOME/.local/bin"
export EDITOR=vim

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(zsh-z)
source $ZSH/oh-my-zsh.sh

eval "$(direnv hook zsh)"

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

# g: short for git
alias g=git
