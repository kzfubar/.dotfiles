# Git Bash on Windows (zsh is the shell on macOS and Ubuntu). Terminal tabs read it through
# .bash_profile; Claude Code's shells source it too, non-interactively.
source "$HOME/.dotfiles/shell/common.sh"

# ln -s makes real Windows symlinks (needs Developer Mode), falling back to a copy
export MSYS=winsymlinks:native

# mise: tools pinned by a project's mise.toml. Shims work in every shell, including
# non-interactive ones; interactive shells also activate it, which updates PATH on cd.
if command -v mise >/dev/null; then
  eval "$(mise activate bash --shims)"
  [[ $- == *i* ]] && eval "$(mise activate bash)"
fi

[[ $- == *i* ]] || return

HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'

command -v starship >/dev/null && eval "$(starship init bash)"
# z <part of a dir>: jump to a frequently used directory, like zsh-z; last, as zoxide asks
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
