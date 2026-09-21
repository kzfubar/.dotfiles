#! /bin/sh

ln -s -f ~/.dotfiles/.vimrc ~/.vimrc
ln -s -f ~/.dotfiles/.gitconfig ~/.gitconfig

mkdir -p ~/.claude/skills
ln -s -f ~/.dotfiles/CLAUDE.md ~/.claude/CLAUDE.md
ln -s -f ~/.dotfiles/claude-settings.json ~/.claude/settings.json

ln -s -f ~/.dotfiles/.zshrc ~/.zshrc
ln -s -f ~/.dotfiles/.gitignore_global ~/.gitignore_global

for skill in ~/.dotfiles/claude-skills/*/; do
	ln -s -f -n "${skill%/}" ~/.claude/skills/"$(basename "$skill")"
done

mkdir -p ~/.local/bin
ln -s -f ~/.dotfiles/tools/gh-board/board ~/.local/bin/board
