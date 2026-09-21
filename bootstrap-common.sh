# Steps shared by bootstrap-macos and bootstrap-ubuntu. Sourced, not run directly.

DOTFILES="$HOME/.dotfiles"

step() { printf '\n==> %s\n' "$*"; }

require_dotfiles_location() {
	if [ "$(pwd -P)" != "$(cd "$DOTFILES" 2>/dev/null && pwd -P)" ]; then
		echo "Clone this repo to $DOTFILES first; link expects it there." >&2
		exit 1
	fi
}

install_oh_my_zsh() {
	step "oh-my-zsh"
	if [ -d "$HOME/.oh-my-zsh" ]; then
		echo "already installed"
	else
		KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
	fi

	local plugin="$HOME/.oh-my-zsh/custom/plugins/zsh-z"
	if [ ! -d "$plugin" ]; then
		git clone --depth 1 https://github.com/agkozak/zsh-z "$plugin"
	fi
}

install_claude_code() {
	step "Claude Code"
	if [ -x "$HOME/.local/bin/claude" ]; then
		echo "already installed"
	else
		curl -fsSL https://claude.ai/install.sh | bash
	fi
}

# Creates the gitignored .gitconfig_local with an empty identity, plus any
# platform-specific git config passed as $1.
stub_gitconfig_local() {
	step "git identity"
	local f="$DOTFILES/.gitconfig_local"
	if [ -f "$f" ]; then
		echo "$f exists"
		return
	fi
	printf '[user]\n  name =\n  email =\n%s' "${1:-}" > "$f"
	echo "Created $f; fill in name and email."
}

stub_board_config() {
	step "gh-board config"
	local f="$DOTFILES/tools/gh-board/board.config.json"
	if [ -f "$f" ]; then
		echo "$f exists"
		return
	fi
	cp "$DOTFILES/tools/gh-board/board.config.example.json" "$f"
	echo "Created $f; fill in org and projectNumber."
}

link_dotfiles() {
	step "symlinks"
	"$DOTFILES/link"
}
