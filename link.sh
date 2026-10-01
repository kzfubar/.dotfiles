#! /bin/sh

link() {
	if [ -e "$2" ] && [ ! -L "$2" ]; then
		echo "skip: $2 exists (not a symlink)"
	else
		ln -s -f -n "$1" "$2"
	fi
}

link ~/.dotfiles/.vimrc ~/.vimrc
link ~/.dotfiles/.gitconfig ~/.gitconfig

mkdir -p ~/.claude/skills
link ~/.dotfiles/CLAUDE.md ~/.claude/CLAUDE.md
link ~/.dotfiles/claude-settings.json ~/.claude/settings.json

link ~/.dotfiles/.zshrc ~/.zshrc
link ~/.dotfiles/.gitignore_global ~/.gitignore_global

for skill in ~/.dotfiles/claude-skills/*/; do
	link "${skill%/}" ~/.claude/skills/"$(basename "$skill")"
done

mkdir -p ~/.local/bin
link ~/.dotfiles/tools/gh-board/board ~/.local/bin/board
link ~/.dotfiles/tools/tnet/tnet ~/.local/bin/tnet
