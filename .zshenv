# Loaded by every zsh, including the non-interactive one that runs `ssh host 'cmd'`.
# .zshrc runs the same line again, after /etc/zprofile's path_helper moves the system
# paths ahead of Homebrew in login shells.
if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
