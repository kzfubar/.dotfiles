# Steps shared by bootstrap-macos and bootstrap-ubuntu. Sourced, not run directly.

DOTFILES="$HOME/.dotfiles"

step() { printf '\n==> %s\n' "$*"; }

require_dotfiles_location() {
	if [ "$(pwd -P)" != "$(cd "$DOTFILES" 2>/dev/null && pwd -P)" ]; then
		echo "Clone this repo to $DOTFILES first; link.sh expects it there." >&2
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

# Clones the private user-harness repo and installs its `uh` command. Needs `gh auth login`,
# which happens after the first bootstrap on a fresh machine, so it skips until then.
install_user_harness() {
	step "user-harness (uh)"
	local dir="$HOME/projects/user-harness"
	if [ ! -d "$dir/.git" ]; then
		if ! gh auth status >/dev/null 2>&1; then
			echo "skipped: run gh auth login, then re-run this bootstrap"
			return
		fi
		mkdir -p "$HOME/projects"
		gh repo clone kzfubar/user-harness "$dir"
	fi
	if [ -x "$HOME/.local/bin/uh" ]; then
		echo "already installed"
	else
		"$(command -v uv || echo "$HOME/.local/bin/uv")" tool install --editable "$dir"
	fi
}

# Creates the gitignored .gitconfig.local with an empty identity, plus any
# platform-specific git config passed as $1.
stub_gitconfig_local() {
	step "git identity"
	local f="$DOTFILES/.gitconfig.local"
	if [ -f "$f" ]; then
		echo "$f exists"
		return
	fi
	printf '[user]\n  name =\n  email =\n%s' "${1:-}" > "$f"
	echo "Created $f; fill in name and email."
}

# Commits are signed on every machine. A machine holding the shared GPG key signs with it;
# any other machine gets its own SSH signing key, so private keys never leave the machine
# they were made on. Run after stub_gitconfig_local.
setup_signing_key() {
	step "commit signing"
	local f="$DOTFILES/.gitconfig.local"
	local key="$HOME/.ssh/id_ed25519_signing"
	local gpg_key
	gpg_key="$(git config --file "$DOTFILES/.gitconfig" user.signingkey)"
	if [ -z "$(git config --file "$f" gpg.format)" ]; then
		if command -v gpg >/dev/null && gpg --list-secret-keys "$gpg_key" >/dev/null 2>&1; then
			echo "signing with GPG key $gpg_key"
			return
		fi
		if [ ! -f "$key" ]; then
			mkdir -p "$HOME/.ssh"
			chmod 700 "$HOME/.ssh"
			ssh-keygen -q -t ed25519 -N '' -C "git signing $(hostname)" -f "$key"
		fi
		git config --file "$f" gpg.format ssh
		git config --file "$f" user.signingkey "$key.pub"
		git config --file "$f" gpg.ssh.allowedSignersFile "$HOME/.ssh/allowed_signers"
		echo "Signing with $key. Add it to GitHub as a signing key (README step 2)."
	else
		echo "configured in $f"
	fi

	[ -f "$key.pub" ] || return 0

	# allowed_signers lets `git log --show-signature` verify this machine's commits locally.
	local email signers="$HOME/.ssh/allowed_signers"
	email="$(git config --file "$f" user.email)"
	if [ -z "$email" ]; then
		echo "Fill in user.email in $f and re-run to record the key in $signers."
	elif ! grep -qF "$(cut -d' ' -f2 "$key.pub")" "$signers" 2>/dev/null; then
		printf '%s namespaces="git" %s\n' "$email" "$(cat "$key.pub")" >> "$signers"
	fi
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
	"$DOTFILES/link.sh"
}

# Installs the marketplaces and plugins declared in claude-settings.json.
install_claude_plugins() {
	step "Claude plugins"
	local settings="$DOTFILES/claude-settings.json"
	local claude
	claude="$(command -v claude || echo "$HOME/.local/bin/claude")"

	jq -r '.extraKnownMarketplaces // {} | .[].source | .repo // .url // .path' "$settings" |
		while read -r source; do
			"$claude" plugin marketplace add "$source"
		done

	jq -r '.enabledPlugins // {} | to_entries[] | select(.value) | .key' "$settings" |
		while read -r plugin; do
			"$claude" plugin install "$plugin"
		done
}
