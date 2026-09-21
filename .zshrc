if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
export PATH="$PATH:$HOME/.local/bin"
export EDITOR=vim

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(zsh-z)
source $ZSH/oh-my-zsh.sh

eval "$(direnv hook zsh)"
